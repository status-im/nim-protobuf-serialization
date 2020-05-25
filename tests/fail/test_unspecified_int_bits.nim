import ../../protobuf_serialization

type UnspecifiedIntBits = object
  x {.sint, fieldNumber: 1.}: int

discard Protobuf.encode(UnspecifiedIntBits())
