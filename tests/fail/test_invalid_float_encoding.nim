import ../../protobuf_serialization

type InvalidFloatEncoding = object
  x {.sint, fieldNumber: 1.}: float32

discard Protobuf.encode(InvalidFloatEncoding())
