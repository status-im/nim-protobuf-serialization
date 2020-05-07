#This check should truly never trigger.
#Why would anyone try to use Protobuf on an Arduino or similar device?
#That said, it is possible, and this library does assume the architecture is one of the two.
#Better safe than sorry.
when sizeof(int) notin {4, 8}:
  {.fatal: "This library only works on 32-bit and 64-bit systems.".}

import macros

import serialization/errors

const
  VAR_INT_CONTINUATION_MASK*: byte = 0b1000_0000
  VAR_INT_VALUE_MASK*: byte = 0b0111_1111

type
  ProtobufError* = object of SerializationError

  ProtoWireType* = enum
    VarInt, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  #Used to specify how to encode/decode primitives.
  PIntWrapped32* = distinct int32
  PIntWrapped64* = distinct int64
  SIntWrapped32* = distinct int32
  SIntWrapped64* = distinct int64
  UIntWrapped32* = distinct uint32
  UIntWrapped64* = distinct uint64
  FixedWrapped32* = distinct uint32
  FixedWrapped64* = distinct uint64
  SFixedWrapped32* = distinct int32
  SFixedWrapped64* = distinct int64

  #Signed native types utilizing the VarInt/Fixed wire types.
  PureSIntegerTypes* = SomeSignedInt or enum
  #Every Signed Integer Type.
  SIntegerTypes* = SIntWrapped32 or SIntWrapped64 or
                   PIntWrapped32 or PIntWrapped64 or
                   SFixedWrapped32 or SFixedWrapped64 or
                   PureSIntegerTypes

  #Unsigned native types utilizing the VarInt/Fixed wire types.
  PureUIntegerTypes* = SomeUnsignedInt or char
  #Every Unsigned Integer Type.
  UIntegerTypes* = UIntWrapped32 or UIntWrapped64 or
                   FixedWrapped32 or FixedWrapped64 or
                   PureUIntegerTypes or bool

  #Every type valid for the VarInt wire tupe.
  VarIntTypes* = SIntegerTypes or UIntegerTypes

  #Limited Fixed types.
  #Limited because there is one other pair of types which fits one of these definitions (int/uint).
  LimitedFixed64Types = int64 or uint64 or float64
  LimitedFixed32Types = int32 or uint32 or float32

  #Castable length delimited types.
  #These can be directly casted from a seq[byte] and do not require a custom converter.
  CastableLengthDelimitedTypes* = string or seq[char or byte or uint8]
  #This type is literally every other type.
  #Every other type is considered custom, due to the need for their own converters.
  #While cstring/array are built-ins, and therefore should have converters provided, but they still need converters.
  LengthDelimitedTypes* = not (VarIntTypes or LimitedFixed64Types or LimitedFixed32Types)

macro generateWrapperConstructors(name: untyped, supported: typed,
                                  smaller: typed, larger: typed,
                                  err: string) =
  quote do:
    template `name`*[T](value: T): untyped =
      when T is not `supported`:
        {.fatal: `err`.}
      elif sizeof(T) == 8:
        `larger`
      else:
        `smaller`

    template `name`*(T: type): untyped =
      when T is not `supported`:
        {.fatal: `err`.}
      elif sizeof(T) == 8:
        `larger`
      else:
        `smaller`

generateWrapperConstructors(PInt, PureSIntegerTypes, PIntWrapped32, PIntWrapped64, "PInt should only be used with a signed integer type.")
generateWrapperConstructors(SInt, PureSIntegerTypes, SIntWrapped32, SIntWrapped64, "SInt should only be used with a signed integer type.")
generateWrapperConstructors(UInt, PureUIntegerTypes, UIntWrapped32, UIntWrapped64, "UInt should only be used with an unsigned integer type.")
generateWrapperConstructors(Fixed, PureUIntegerTypes, FixedWrapped32, FixedWrapped64, "Fixed should only be used with an unsigned integer type.")
generateWrapperConstructors(SFixed, PureSIntegerTypes, SFixedWrapped32, SFixedWrapped64, "SFixed should only be used with a signed integer type.")

#Used to specify how to encode/decode fields in an object.
template pint*() {.pragma.}
template puint*() {.pragma.}
template sint*() {.pragma.}
template fixed*() {.pragma.}
template sfixed*() {.pragma.}

#Full definitions for the Fixed Types.
when sizeof(int) == 4:
  type
    Fixed64Types* = LimitedFixed64Types
    Fixed32Types* = LimitedFixed32Types or int
else:
  type
    Fixed64Types* = LimitedFixed64Types or int
    Fixed32Types* = LimitedFixed32Types

#Legacy types being phased out.
type
  ProtoField*[T] = object
    index*: int
    value*: T
  SomeLengthDelimited* = CastableLengthDelimitedTypes or cstring
  AnyProtoType* = VarIntTypes or Fixed64Types or CastableLengthDelimitedTypes or Fixed32Types or object
