from macros import quote

import stew/bitops2
import faststreams

const
  VAR_INT_CONTINUATION_MASK*: byte = 0b1000_0000
  VAR_INT_VALUE_MASK*: byte = 0b0111_1111

type
  VarIntStatus* = enum
    Success,
    Overflow,
    Incomplete

  #Used to specify how to encode/decode primitives.
  #Despite being used outside of this library, all access is via templates.
  PIntWrapped32   = distinct int32
  PIntWrapped64   = distinct int64
  UIntWrapped32   = distinct uint32
  UIntWrapped64   = distinct uint64
  SIntWrapped32   = distinct int32
  SIntWrapped64   = distinct int64
  FixedWrapped32  = distinct uint32
  FixedWrapped64  = distinct uint64
  SFixedWrapped32 = distinct int32
  SFixedWrapped64 = distinct int64

  LUIntWrapped32 = distinct int32
  LUIntWrapped64 = distinct int64

  SignedWrapped32Types   = PIntWrapped32 or SIntWrapped32 or SFixedWrapped32
  SignedWrapped64Types   = PIntWrapped64 or SIntWrapped64 or SFixedWrapped64
  UnsignedWrapped32Types = UIntWrapped32 or FixedWrapped32 or LUIntWrapped32
  UnsignedWrapped64Types = UIntWrapped64 or FixedWrapped64 or LUIntWrapped64

  PIntWrapped  = PIntWrapped32 or PIntWrapped64
  SIntWrapped  = SIntWrapped32 or SIntWrapped64
  UIntWrapped  = UIntWrapped32 or UIntWrapped64
  LUIntWrapped = LUIntWrapped32 or LUIntWrapped64

  VarIntWrapped* = PIntWrapped or SIntWrapped or
                   UIntWrapped or LUIntWrapped
  FixedWrapped*  = FixedWrapped32 or FixedWrapped64 or
                   SFixedWrapped32 or SFixedWrapped64

  #Signed native types utilizing the VarInt/Fixed wire types.
  PureSIntegerTypes = SomeSignedInt or enum
  #Every Signed Integer Type.
  SIntegerTypes* = PIntWrapped32 or PIntWrapped64 or
                   SIntWrapped32 or SIntWrapped64 or
                   SFixedWrapped32 or SFixedWrapped64 or
                   PureSIntegerTypes

  #Unsigned native types utilizing the VarInt/Fixed wire types.
  PureUIntegerTypes = SomeUnsignedInt or char or bool
  #Every Unsigned Integer Type.
  UIntegerTypes* = UIntWrapped or FixedWrapped or
                   LUIntWrapped or PureUIntegerTypes

  PureTypes* = PureSIntegerTypes or PureUIntegerTypes

  #Every type valid for the VarInt wire type.
  VarIntTypes* = SIntegerTypes or UIntegerTypes
  #Every type valid for the Fixed (32 or 64) wire type.
  FixedTypes* = FixedWrapped or
                PureUIntegerTypes or PureSIntegerTypes or
                float32 or float64

macro generateWrapper(
  name: untyped,
  supported: typed,
  uLarger: typed,
  uSmaller: typed,
  sLarger: typed,
  sSmaller: typed,
  err: string
): untyped =
  quote do:
    template `name`*(value: untyped): untyped =
      when value is not `supported`:
        {.fatal: `err`.}

      when value is type:
        when value is UIntegerTypes:
          when sizeof(value) == 8:
            `uLarger`
          else:
            `uSmaller`
        else:
          when sizeof(value) == 8:
            `sLarger`
          else:
            `sSmaller`
      else:
        when value is UIntegerTypes:
          when sizeof(value) == 8:
            `uLarger`(value)
          else:
            `uSmaller`(value)
        else:
          when sizeof(value) == 8:
            #Use a binary cast so we can convert floats.
            #Required for Fixed; has no effect on any type.
            cast[`sLarger`](value)
          else:
            cast[`sSmaller`](value)

generateWrapper(
  SInt, SIntegerTypes,
  SIntWrapped32,  SIntWrapped64,
  SIntWrapped32,  SIntWrapped64,
  "SInt should only be used with signed integers."
)

generateWrapper(
  PInt, SIntegerTypes or UIntegerTypes,
  UIntWrapped64, UIntWrapped32,
  PIntWrapped64, PIntWrapped32,
  "LInt should only be used with integers (signed or unsigned)."
)

generateWrapper(
  Fixed, FixedTypes,
  FixedWrapped64, FixedWrapped32,
  SFixedWrapped64, SFixedWrapped32,
  "Fixed should only be used with a number."
)

generateWrapper(
  LInt, UIntegerTypes,
  LUIntWrapped64, LUIntWrapped32,
  LUIntWrapped64, LUIntWrapped32,
  "LInt should only be used with unsigned integers."
)

#Used to specify how to encode/decode fields in an object.
template pint*() {.pragma.}
template sint*() {.pragma.}
template fixed*() {.pragma.}
template lint*() {.pragma.}

template unwrap*[T](value: T): untyped =
  when T is SignedWrapped32Types:
    int32(value)
  elif T is SignedWrapped64Types:
    int64(value)
  elif T is UnsignedWrapped32Types:
    uint32(value)
  elif T is UnsignedWrapped64Types:
    uint64(value)
  else:
    {.fatal: "Tried to get the unwrapped value of a non-wrapped type. This should never happen.".}

func encodeBinaryValue(value: VarIntWrapped): auto =
  when sizeof(value) == 8:
    result = cast[uint64](value)
  else:
    result = cast[uint32](value)

  mixin unwrap
  when value is PIntWrapped:
    if value.unwrap() < 0:
      result = not result
  elif value is SIntWrapped:
    #This line is the formula exactly as described in the Protobuf docs.
    #That said, it's quite verbose.
    #The below formula which is actually used is much simpler and possibly faster.
    #This is preserved to note it, but not to be used.
    #result = (result shl 1) xor cast[type(result)](ashr(value.unwrap(), (sizeof(result) * 8) - 1))
    result = result shl 1
    if value.unwrap() < 0:
      result = not result
  elif value is UIntWrapped:
    discard
  else:
    {.fatal: "Tried to get the binary value of an unrecognized VarInt type.".}

func viSizeof(base: VarIntWrapped, raw: uint32 or uint64): int =
  when base is PIntWrapped:
    if base.unwrap() < 0:
      return 10
  result = max((log2trunc(raw) + 7) div 7, 1)

func encodeVarInt*(
  res: var openarray[byte],
  outLen: var int,
  value: VarIntWrapped
): VarIntStatus =
  #Verify the value fits into the specified encoding.
  when value is (LUIntWrapped32 or LUIntWrapped64):
    if value shr 63 != 0:
      return VarIntStatus.Overflow

    #Get the binary value of whatever we're decoding.
    #Beyond the above check, LibP2P uses the standard UInt encoding.
    #That's why we perform this cast.
    var raw = encodeBinaryValue(PInt(value))
  else:
    var raw = encodeBinaryValue(value)

  outLen = viSizeof(value, raw)

  #Verify there's enough bytes to store this value.
  if res.len < outLen:
    return VarIntStatus.Incomplete

  #Write the VarInt.
  var i = 0
  while raw > type(raw)(VAR_INT_VALUE_MASK):
    res[i] = byte(raw and type(raw)(VAR_INT_VALUE_MASK)) or VAR_INT_CONTINUATION_MASK
    inc(i)
    raw = raw shr 7

  #If this was a positive number (PInt or UInt), or zig-zagged, we only need to write this last byte.
  when value is PIntWrapped:
    if value.unwrap() >= 0:
      res[i] = byte(raw)
    else:
      #[
      To signify this is negative, this should be artifically padded to 10 bytes.
      That said, we have to write the final pending byte left in raw, as well as masks until then.
      #This iterates up to 9.
      We don't immediately write the final pending byte and then loop.
      Why? Because if all 9 bytes were used, it'll set the continuation flag when it shouldn't.
      If all 9 bytes were used, the last byte is 0 anyways.
      By setting raw to 0, which is pointless after the first loop, we avoid two conditionals.
      ]#
      while i < 9:
        res[i] = VAR_INT_CONTINUATION_MASK or byte(raw)
        inc(i)
        raw = 0
  else:
    res[i] = byte(raw)

func encodeVarInt*(value: VarIntWrapped): seq[byte] =
  result = newSeq[byte](10)
  var outLen: int
  doAssert encodeVarInt(result, outLen, value) == VarIntStatus.Success
  result.setLen(outLen)

proc encodeVarInt*(stream: OutputStream, value: VarIntWrapped) {.inline.} =
  stream.write(encodeVarInt(value))

func decodeBinaryValue[E](
  res: var E,
  value: uint32 or uint64,
  len: int
): VarIntStatus =
  when sizeof(E) != sizeof(value):
    {.fatal: "Tried to decode a raw binary value into an encoding with a different size. This should never happen.".}

  when E is (PIntWrapped or LUIntWrapped):
    if res.unwrap() shr ((sizeof(res) * 8) - 1) == 1:
      return VarIntStatus.Overflow

    when E is PIntWrapped:
      if len == 10:
        type S = type(res.unwrap())
        res = E(-S(value + 1))
      else:
        res = E(value)
    else:
      res = E(value)

  elif E is SIntWrapped:
    type S = type(res.unwrap())
    res = E(S(value shr 1) xor -S(value and 0b0000_0001))

  elif E is UIntWrapped:
    res = E(value)

  else:
    {.fatal: "Tried to decode a raw binary value into an unrecognized type. This should never happen.".}

  return VarIntStatus.Success

proc decodeVarInt*(
  bytes: openarray[byte],
  inLen: var int,
  res: var VarIntWrapped
): VarIntStatus =
  when sizeof(res) == 8:
    type U = uint64
  else:
    type U = uint32

  var
    value: U
    offset = 0'i8
    next = VAR_INT_CONTINUATION_MASK
  while (next and VAR_INT_CONTINUATION_MASK) != 0:
    if inLen == bytes.len:
      return VarIntStatus.Incomplete
    next = bytes[inLen]
    value += (next and U(VAR_INT_VALUE_MASK)) shl offset
    inLen += 1
    offset += 7

  doAssert decodeBinaryValue(res, value, inLen) == VarIntStatus.Success

proc decodeVarInt*[R, E](
  stream: InputStream,
  returnType: typedesc[R],
  encoding: typedesc[E]
): R =
  var
    bytes: seq[byte]
    next: byte = VAR_INT_CONTINUATION_MASK
    value: E
    inLen: int

  while (next and VAR_INT_CONTINUATION_MASK) != 0:
    if not stream.readable():
      raise newException(ProtobufEOFError, "Stream ended before the VarInt was finished.")
    next = stream.read()
    bytes.add(next)

  doAssert decodeVarInt(bytes, inLen, value) == VarIntStatus.Success
  doAssert inLen == bytes.len
  #Removes a warning.
  when value is R:
    result = value
  else:
    result = R(value)
