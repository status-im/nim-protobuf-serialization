import serialization/errors

#int32 is a keywork. pint32 standards for Protobuf int32.
#sint32 is just sint32; sfixed32 is just sfixed32; double is just double.
template pint32*() {.pragma.}
template pint64*() {.pragma.}
template sint32*() {.pragma.}
template sint64*() {.pragma.}
template fixed32*() {.pragma.}
template fixed64*() {.pragma.}
template sfixed32*() {.pragma.}
template sfixed64*() {.pragma.}
template double*() {.pragma.}

const
  VAR_INT_CONTINUATION_MASK*: byte = 0b1000_0000
  VAR_INT_VALUE_MASK*: byte = 0b0111_1111

type
  ProtoWireType* = enum
    VarInt, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  SubType* = enum
    Default
    PInt32,
    PInt64,
    UInt32,
    UInt64,
    SInt32,
    SInt64,
    PBool,
    PEnum

  ProtoField*[T] = object
    index*: int
    value*: T

  Integer32Types* = byte or char or int8 or int16 or int32
  UInteger32Types* = uint8 or uint16 or uint32
  CastableLengthDelimitedTypes* = string or seq[char or byte or uint8]
  LengthDelimitedTypes* = CastableLengthDelimitedTypes or cstring or array or object

  ProtobufError* = object of SerializationError
