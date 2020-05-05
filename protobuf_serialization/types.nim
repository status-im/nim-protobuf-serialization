template sint32*() {.pragma.}
template sint64*() {.pragma.}
template sfixed32*() {.pragma.}
template sfixed64*() {.pragma.}
template fixed32*() {.pragma.}
template fixed64*() {.pragma.}
template float*() {.pragma.}
template double*() {.pragma.}

type
  ProtoWireType* = enum
    ## Protobuf's field types enum
    Varint, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  EncodingKind* = enum
    ekNormal, ekZigzag

  ProtoField*[T] = object
    ## Protobuf's message field representation object
    index*: int
    value*: T

  SomeSVarint* = int | int64 | int32 | int16 | int8 | enum
  SomeByte* = byte | bool | char | uint8
  SomeUVarint* = uint | uint64 | uint32 | uint16 | SomeByte
  SomeVarint* = SomeSVarint | SomeUVarint
  SomeLengthDelimited* = string | seq[SomeByte] | cstring
  SomeFixed64* = float64
  SomeFixed32* = float32
  SomeFixed* = SomeFixed32 | SomeFixed64

  AnyProtoType* = SomeVarint | SomeLengthDelimited | SomeFixed | object

  UnexpectedTypeError* = object of ValueError
