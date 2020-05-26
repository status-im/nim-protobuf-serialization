import ../../protobuf_serialization

type InvalidFloatEncoding = object
  x {.pint, pfloat32, fieldNumber: 1.}: float32

discard Protobuf.encode(InvalidFloatEncoding())
