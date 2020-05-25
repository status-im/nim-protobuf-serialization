import ../../protobuf_serialization

type NoFloatEncoding = object
  x {.fieldNumber: 1.}: float32

discard Protobuf.encode(NoFloatEncoding())
