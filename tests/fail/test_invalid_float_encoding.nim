import ../../protobuf_serialization

type InvalidFloatEncoding = object
  x {.pint, fieldNumber: 1.}: float32

discard Protobuf.encode(InvalidFloatEncoding())
