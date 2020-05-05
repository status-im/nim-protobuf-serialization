import serialization/errors

#int32 is a keywork. pint32 standards for Protobuf int32.
#sint32 is just sint32; sfixed32 is just sfixed32; double is just double.
template pint*() {.pragma.}
template sint*() {.pragma.}
template fixed32*() {.pragma.}
template fixed64*() {.pragma.}
template sfixed32*() {.pragma.}
template sfixed64*() {.pragma.}

const
  VAR_INT_CONTINUATION_MASK*: byte = 0b1000_0000
  VAR_INT_VALUE_MASK*: byte = 0b0111_1111

type
  ProtoWireType* = enum
    VarInt, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  SubType* = enum
    Default,
    PInt,
    SInt

  ProtoField*[T] = object
    index*: int
    value*: T

  SIntegerTypes = SomeSignedInt or enum
  UIntegerTypes = SomeUnsignedInt or bool
  IntegerTypes = SIntegerTypes or UIntegerTypes
  CastableLengthDelimitedTypes* = string or seq[char or byte or uint8]
  LengthDelimitedTypes* = CastableLengthDelimitedTypes or cstring or array or object

  ProtobufError* = object of SerializationError

