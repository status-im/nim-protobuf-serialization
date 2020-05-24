from macros import quote

import stew/bitops2
import faststreams

const
  VAR_INT_CONTINUATION_MASK*: byte = 0b1000_0000
  VAR_INT_VALUE_MASK*: byte = 0b0111_1111

type
  VarintStatus* = enum
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

  LIntWrapped32  = distinct int32
  LIntWrapped64  = distinct int64
  LUIntWrapped32 = distinct int32
  LUIntWrapped64 = distinct int64

  SignedWrapped32Types   = PIntWrapped32 or SIntWrapped32 or SFixedWrapped32 or LIntWrapped32
  SignedWrapped64Types   = PIntWrapped64 or SIntWrapped64 or SFixedWrapped64 or LIntWrapped64
  UnsignedWrapped32Types = UIntWrapped32 or FixedWrapped32 or LUIntWrapped32
  UnsignedWrapped64Types = UIntWrapped64 or FixedWrapped64 or LUIntWrapped64

  PIntWrapped    = PIntWrapped32 or PIntWrapped64
  SIntWrapped    = SIntWrapped32 or SIntWrapped64
  UIntWrapped    = UIntWrapped32 or UIntWrapped64
  VarIntWrapped* = PIntWrapped or SIntWrapped or UIntWrapped or
                   LIntWrapped32 or LIntWrapped64 or
                   LUIntWrapped32 or LUIntWrapped64
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
  UIntegerTypes* = UIntWrapped32 or UIntWrapped64 or
                   FixedWrapped32 or FixedWrapped64 or
                   PureUIntegerTypes

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
  "SInt should only be used with a signed integer type."
)

generateWrapper(
  PInt, SIntegerTypes or UIntegerTypes,
  UIntWrapped64, UIntWrapped32,
  PIntWrapped64, PIntWrapped32,
  "LInt should only be used with a integer value (signed or unsigned)."
)

generateWrapper(
  Fixed, FixedTypes,
  FixedWrapped64, FixedWrapped32,
  SFixedWrapped64, SFixedWrapped32,
  "Fixed should only be used with a number."
)

generateWrapper(
  LInt, SIntegerTypes or UIntegerTypes,
  LUIntWrapped64, LUIntWrapped32,
  LIntWrapped64, LIntWrapped32,
  "LInt should only be used with a integer value (signed or unsigned)."
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

func getBinaryValue(value: VarIntWrapped): auto =
  when sizeof(value) == 8:
    result = cast[uint64](value)
  else:
    result = cast[uint32](value)

  mixin unwrap
  when value is PIntWrapped:
    if value.unwrap() < 0:
      result = not result
  elif value is SIntWrapped:
    result = (result shl 1) xor cast[type(result)](ashr(value.unwrap(), (sizeof(result) * 8) - 1))

func viSizeof(base: VarIntWrapped, raw: uint32 or uint64): int =
  when base is PIntWrapped:
    if base.unwrap() < 0:
      return 10
  result = (log2trunc(raw) + 7) div 7

func encodeVarInt*(value: VarIntWrapped): seq[byte] =
  #Get the binary value of whatever we're decoding.
  var
    raw = getBinaryValue(value)
    bytesNeeded = viSizeof(value, raw)
  #Always return at least one byte.
  if bytesNeeded == 0:
    return @[byte(0)]
  result = newSeq[byte](bytesNeeded)

  #Write the VarInt.
  var i = 0
  while raw > type(raw)(VAR_INT_VALUE_MASK):
    #We could convert raw to a byte, but that'll trigger a bounds check.
    result[i] = byte(raw and type(raw)(VAR_INT_VALUE_MASK)) or VAR_INT_CONTINUATION_MASK
    inc(i)
    raw = raw shr 7

  #If this was a positive number (PInt or UInt), or zig-zagged, we only need to write this last byte.
  when value is PIntWrapped:
    if value.unwrap() > 0:
      result[i] = byte(raw)
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
        result[i] = VAR_INT_CONTINUATION_MASK or byte(raw)
        inc(i)
        raw = 0
  else:
    result[i] = byte(raw)

proc decodeVarInt*[R, E](
  stream: InputStream,
  returnType: typedesc[R],
  encoding: typedesc[E]
): R =
  when sizeof(E) == 8:
    type
      S = int64
      U = uint64
  else:
    type
      S = int32
      U = uint32

  var
    value = U(0)
    offset = 0'i8
    next = VAR_INT_CONTINUATION_MASK
  while (next and VAR_INT_CONTINUATION_MASK) != 0:
    if not stream.readable():
      raise newException(IOError, "Couldn't read the next byte from this stream despite expecting one.")
    next = stream.read()
    value += (next and U(VAR_INT_VALUE_MASK)) shl offset
    offset += 7

  #Unsigned, requiring no further work.
  when E is UIntWrapped:
    result = R(value)
  #Zig-zagged.
  elif E is SIntWrapped:
    result = R(S(value shr 1) xor -S(value and U(0b0000_0001)))
  else:
    #Not zig-zagged, yet negative.
    if offset == 70:
      #This should handle the lowest possible negative value.
      #The cast to a signed value causes it to error/wrap to the lowest value.
      #Said lowest value will be negative, multiplied by -1, and wrap again.
      #This behavior requires boundChecks to be turned off in order to not raise though.
      {.push boundChecks: off.}
      result = R(-S(value + 1))
      {.pop.}
    #Not zig-zagged, yet positive.
    else:
      result = R(value)
