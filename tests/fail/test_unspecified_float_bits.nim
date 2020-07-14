import ../../protobuf_serialization

type UnspecifiedFloatBits = object
  x {.fieldNumber: 1.}: float64

discard Protobuf.encode(UnspecifiedFloatBits())
