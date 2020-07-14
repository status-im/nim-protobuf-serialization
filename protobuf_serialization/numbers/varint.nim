import stew/bitops2
import faststreams

import common
export PureTypes
export ProtobufError, ProtobufReadError, ProtobufEOFError, ProtobufMessageError

const
  VAR_INT_CONTINUATION_MASK*: byte = 0b1000_0000
  VAR_INT_VALUE_MASK: byte = 0b0111_1111

type
  VarIntStatus* = enum
    Success,
    Overflow,
    Incomplete

  #Used to specify how to encode/decode primitives.
  #Despite being used outside of this library, all access is via templates.
  PIntWrapped32  = distinct int32
  PIntWrapped64  = distinct int64
  SIntWrapped32  = distinct int32
  SIntWrapped64  = distinct int64
  UIntWrapped32  = distinct uint32
  UIntWrapped64  = distinct uint64
  LUIntWrapped32 = distinct uint32
  LUIntWrapped64 = distinct uint64

  #Types which share an encoding.
  PIntWrapped  = PIntWrapped32 or PIntWrapped64
  SIntWrapped  = SIntWrapped32 or SIntWrapped64
  UIntWrapped  = UIntWrapped32 or UIntWrapped64 or
                 byte or char or bool
  LUIntWrapped* = LUIntWrapped32 or LUIntWrapped64

  #Any wrapped VarInt types.
  VarIntWrapped* = PIntWrapped or SIntWrapped or
                   UIntWrapped or LUIntWrapped

  #Every signed integer Type.
  SIntegerTypes = PureSIntegerTypes or
                  PIntWrapped32 or PIntWrapped64 or
                  SIntWrapped32 or SIntWrapped64

  #Every unsigned integer Type.
  UIntegerTypes = PureUIntegerTypes or UIntWrapped or LUIntWrapped

  #Every type valid for the VarInt wire type.
  VarIntTypes* = SIntegerTypes or UIntegerTypes

generateWrapper(
  PInt, UIntegerTypes or SIntegerTypes, VarIntWrapped,
  UIntegerTypes, UIntWrapped64, UIntWrapped32,
  SIntegerTypes, PIntWrapped64, PIntWrapped32,
  "LInt should only be used with integers (signed or unsigned)."
)

generateWrapper(
  SInt, SIntegerTypes, VarIntWrapped,
  void, void, void,
  SIntegerTypes, SIntWrapped64,  SIntWrapped32,
  "SInt should only be used with signed integers."
)

generateWrapper(
  LInt, UIntegerTypes, VarIntWrapped,
  UIntegerTypes, LUIntWrapped64, LUIntWrapped32,
  void, void, void,
  "LInt should only be used with unsigned integers."
)

#Used to specify how to encode/decode fields in an object.
template pint*() {.pragma.}
template sint*() {.pragma.}

template unwrap*(value: VarIntWrapped): untyped =
  when value is (PIntWrapped32 or SIntWrapped32):
    int32(value)
  elif value is (PIntWrapped64 or SIntWrapped64):
    int64(value)
  elif value is (UIntWrapped32 or LUIntWrapped32):
    uint32(value)
  elif value is (UIntWrapped64 or LUIntWrapped64):
    uint64(value)
  elif value is UIntWrapped:
    value
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
  when value is LUIntWrapped:
    when sizeof(value) == 8:
      if value.unwrap() shr 63 != 0:
        return VarIntStatus.Overflow

    #Get the binary value of whatever we're decoding.
    #Beyond the above check, LibP2P uses the standard UInt encoding.
    #That's why we perform this cast.
    var raw = encodeBinaryValue(PInt(value.unwrap()))
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
    if value.unwrap() < 0:
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
  else:
    res[i] = byte(raw)

func encodeVarInt*(value: VarIntWrapped): seq[byte] =
  result = newSeq[byte](10)
  var outLen: int
  if encodeVarInt(result, outLen, value) != VarIntStatus.Success:
    when value is LUIntWrapped:
      {.fatal: "LibP2P VarInts require using the following signature: `encodeVarInt(var openarray[byte], outLen: var int, value: VarIntWrapped): VarIntStatus`.".}
    else:
      doAssert(false)
  result.setLen(outLen)

proc encodeVarInt*(stream: OutputStream, value: VarIntWrapped) {.inline.} =
  stream.write(encodeVarInt(value))

func decodeBinaryValue[E](
  res: var E,
  value: uint32 or uint64,
  len: int
): VarIntStatus =
  when (sizeof(E) != sizeof(value)) and (sizeof(E) != 1):
    {.fatal: "Tried to decode a raw binary value into an encoding with a different size. This should never happen.".}

  when E is LUIntWrapped:
    if res.unwrap() shr ((sizeof(res) * 8) - 1) == 1:
      return VarIntStatus.Overflow
    res = E(value)

  elif E is PIntWrapped:
    if len == 10:
      type S = type(res.unwrap())
      res = E((-S(value)) - 1)
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

func decodeVarInt*(
  bytes: openarray[byte],
  inLen: var int,
  res: var VarIntWrapped
): VarIntStatus =
  when sizeof(res) == 8:
    type U = uint64
    var maxBits = 64
  else:
    type U = uint32
    var maxBits = 32

  when (res is LUIntWrapped) and (sizeof(res) == 8):
    maxBits = 63

  var
    value: U
    offset = 0'i8
    next = VAR_INT_CONTINUATION_MASK
  while (next and VAR_INT_CONTINUATION_MASK) != 0:
    if inLen == bytes.len:
      return VarIntStatus.Incomplete
    next = bytes[inLen]
    if (next and VAR_INT_VALUE_MASK) == 0:
      inLen += 1
      offset += 7
      continue

    if (offset + log2trunc(next and VAR_INT_VALUE_MASK) + 1) > maxBits:
      return VarIntStatus.Overflow

    value += (next and U(VAR_INT_VALUE_MASK)) shl offset
    inLen += 1
    offset += 7

  return decodeBinaryValue(res, value, inLen)

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

  if decodeVarInt(bytes, inLen, value) != VarIntStatus.Success:
    raise newException(ProtobufMessageError, "Attempted to decode an invalid VarInt.")
  doAssert inLen == bytes.len

  #Removes a warning.
  when value is R:
    result = value
  else:
    result = R(value)
