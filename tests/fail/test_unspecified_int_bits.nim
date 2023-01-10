import ../../protobuf_serialization

type UnspecifiedIntBits {.proto3.} = object
  x {.sint, fieldNumber: 1.}: int

discard Protobuf.encode(UnspecifiedIntBits())
