#Variables needed by the Reader and Writer which should NOT be exported outside of this library.

#This check should truly never trigger.
#Why would anyone try to use Protobuf on an Arduino or similar device?
#That said, it is possible, and this library does assume the architecture is one of the two.
#Better safe than sorry.
when sizeof(int) notin {4, 8}:
  {.fatal: "This library only works on 32-bit and 64-bit systems.".}

const
  VAR_INT_CONTINUATION_MASK*: byte = 0b1000_0000
  VAR_INT_VALUE_MASK*: byte = 0b0111_1111

type
  ProtoWireType* = enum
    VarInt, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  VarIntSubType* = enum
    PIntSubType,
    SIntSubType,
    UIntSubType
    FixedSubType,
    SFixedSubType

  #Used to specify how to encode/decode primitives.
  #Despite being used outside of this library, all access is via templates.
  PIntWrapped32* = distinct int32
  PIntWrapped64* = distinct int64
  UIntWrapped32* = distinct uint32
  UIntWrapped64* = distinct uint64
  SIntWrapped32* = distinct int32
  SIntWrapped64* = distinct int64
  FixedWrapped32* = distinct uint32
  FixedWrapped64* = distinct uint64
  SFixedWrapped32* = distinct int32
  SFixedWrapped64* = distinct int64

  #Signed native types utilizing the VarInt/Fixed wire types.
  PureSIntegerTypes* = SomeSignedInt or enum
  #Every Signed Integer Type.
  SIntegerTypes* = PIntWrapped32 or PIntWrapped64 or
                   SIntWrapped32 or SIntWrapped64 or
                   SFixedWrapped32 or SFixedWrapped64 or
                   PureSIntegerTypes

  #Unsigned native types utilizing the VarInt/Fixed wire types.
  PureUIntegerTypes* = SomeUnsignedInt or char or bool
  #Every Unsigned Integer Type.
  UIntegerTypes* = UIntWrapped32 or UIntWrapped64 or
                   FixedWrapped32 or FixedWrapped64 or
                   PureUIntegerTypes

  #Every wrapped type that can be used with the VarInt wire type.
  WrappedVarIntTypes* = PIntWrapped32 or PIntWrapped64 or
                        SIntWrapped32 or SIntWrapped64 or
                        UIntWrapped32 or UIntWrapped64
  #Every type valid for the VarInt wire type.
  VarIntTypes* = SIntegerTypes or UIntegerTypes

  #Limited Fixed types.
  #Limited because there is one other pair of types which fits one of these definitions (int/uint).
  LimitedFixed64Types = int64 or uint64 or float64 or FixedWrapped64 or SFixedWrapped64
  LimitedFixed32Types = int32 or uint32 or float32 or FixedWrapped32 or SFixedWrapped32

  #Castable length delimited types.
  #These can be directly casted from a seq[byte] and do not require a custom converter.
  CastableLengthDelimitedTypes* = string or seq[char or byte or uint8 or bool]
  #This type is literally every other type.
  #Every other type is considered custom, due to the need for their own converters.
  #While cstring/array are built-ins, and therefore should have converters provided, but they still need converters.
  LengthDelimitedTypes* = not (VarIntTypes or LimitedFixed64Types or LimitedFixed32Types)

#Full definitions for the Fixed Types.
when sizeof(int) == 4:
  type
    Fixed64Types* = LimitedFixed64Types
    Fixed32Types* = LimitedFixed32Types or int
else:
  type
    Fixed64Types* = LimitedFixed64Types or int
    Fixed32Types* = LimitedFixed32Types

template unwrap*[T](value: T): untyped =
  when T is (PIntWrapped32 or SIntWrapped32 or SFixedWrapped32):
    int32(value)
  elif T is (PIntWrapped64 or SIntWrapped64 or SFixedWrapped64):
    int64(value)
  elif T is (UIntWrapped32 or FixedWrapped32):
    uint32(value)
  elif T is (UIntWrapped64 or FixedWrapped64):
    uint64(value)
  else:
    {.fatal: "Tried to get the unwrapped value of a non-wrapped type. This should never happen.".}
