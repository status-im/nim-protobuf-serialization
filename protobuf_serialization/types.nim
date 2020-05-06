when sizeof(int) notin {4, 8}:
  {.fatal: "This library only works on 32-bit and 64-bit systems.".}

import serialization/errors

#int32 is a keywork. pint32 standards for Protobuf int32.
#sint32 is just sint32; sfixed32 is just sfixed32; double is just double.
template pint*() {.pragma.}
template sint*() {.pragma.}
template fixed*() {.pragma.}
template sfixed*() {.pragma.}

const
  VAR_INT_CONTINUATION_MASK*: byte = 0b1000_0000
  VAR_INT_VALUE_MASK*: byte = 0b0111_1111

type
  ProtoWireType* = enum
    VarInt, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  VarIntSubType* = enum
    Default,
    PInt,
    SInt

  ProtoField*[T] = object
    index*: int
    value*: T

  SIntegerTypes* = SomeSignedInt or char or enum
  UIntegerTypes* = SomeUnsignedInt or bool
  IntegerTypes* = SIntegerTypes or UIntegerTypes

  VarIntTypes* = IntegerTypes
  LimitedFixed64Types = int64 or uint64 or float64
  LimitedFixed32Types = int32 or uint32 or float32
  CastableLengthDelimitedTypes* = string or seq[char or byte or uint8]
  LengthDelimitedTypes* = CastableLengthDelimitedTypes or cstring or array or object

  ProtobufError* = object of SerializationError

when sizeof(int) == 4:
  type
    Fixed64Types* = LimitedFixed64Types
    Fixed32Types* = LimitedFixed32Types or int
else:
  type
    Fixed64Types* = LimitedFixed64Types or int
    Fixed32Types* = LimitedFixed32Types

type
  SomeSVarint* = int | int64 | int32 | int16 | int8 | enum
  SomeByte* = byte | bool | char | uint8
  SomeUVarint* = uint | uint64 | uint32 | uint16 | SomeByte
  SomeVarint* = SomeSVarint | SomeUVarint
  SomeLengthDelimited* = string | seq[SomeByte] | cstring
  SomeFixed64* = float64
  SomeFixed32* = float32
  SomeFixed* = SomeFixed32 | SomeFixed64
  AnyProtoType* = SomeVarint | SomeLengthDelimited | SomeFixed | object
