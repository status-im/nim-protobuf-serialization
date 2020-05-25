import ../../protobuf_serialization

type UnspecifiedFloatBits = object
  x {.fixed, fieldNumber: 1.}: float

discard Protobuf.encode(UnspecifiedFloatBits())
