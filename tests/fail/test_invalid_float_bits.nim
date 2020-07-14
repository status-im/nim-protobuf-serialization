import ../../protobuf_serialization

type InvalidFloatBits = object
  x {.pfloat32, fieldNumber: 1.}: float64

discard Protobuf.encode(InvalidFloatBits())
