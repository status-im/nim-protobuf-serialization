import ../../protobuf_serialization

type SpecifiedFloatEncoding = object
  x {.fixed, fieldNumber: 1.}: float32

discard Protobuf.encode(SpecifiedFloatEncoding())
