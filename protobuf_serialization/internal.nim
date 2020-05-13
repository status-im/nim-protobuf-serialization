#Variables needed by the Reader and Writer which should NOT be exported outside of this library.

const
  VAR_INT_CONTINUATION_MASK*: byte = 0b1000_0000
  VAR_INT_VALUE_MASK*: byte = 0b0111_1111

type
  ProtobufWireType* = enum
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

  #Number types which are platform-dependent and therefore unsafe.
  PlatformDependentTypes* = (not (int32 or int64 or uint32 or uint64 or float32 or float64)) and (int or uint or float)
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
                        UIntWrapped32 or UIntWrapped64 or
                        SIntWrapped32 or SIntWrapped64
  #Every wrapped type that can be used with the Fixed wire types.
  WrappedFixedTypes* = FixedWrapped32 or FixedWrapped64 or
                       SFixedWrapped32 or SFixedWrapped64
  #Every type valid for the VarInt wire type.
  VarIntTypes* = SIntegerTypes or UIntegerTypes

  #Fixed types.
  FixedTypes* = UIntegerTypes or FixedWrapped64 or FixedWrapped32
  SFixedTypes* = SIntegerTypes or SomeFloat or SFixedWrapped64 or SFixedWrapped32
  Fixed64Types* = int64 or uint64 or float64 or FixedWrapped64 or SFixedWrapped64
  Fixed32Types* = int32 or uint32 or float32 or FixedWrapped32 or SFixedWrapped32

  #Castable length delimited types.
  #These can be directly casted from a seq[byte] and do not require a custom converter.
  CastableLengthDelimitedTypes* = string or seq[char or byte or uint8 or bool]
  #This type is literally every other type.
  #Every other type is considered custom, due to the need for their own converters.
  #While cstring/array are built-ins, and therefore should have converters provided, but they still need converters.
  LengthDelimitedTypes* = not (VarIntTypes or Fixed64Types or Fixed32Types)

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
