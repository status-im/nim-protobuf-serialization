import ../../protobuf_serialization

type UnspecifiedUIntBits {.proto3.} = object
  x {.pint, fieldNumber: 1.}: uint

discard Protobuf.encode(UnspecifiedUIntBits())
