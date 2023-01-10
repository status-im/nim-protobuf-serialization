import ../../protobuf_serialization

type InvalidFloatEncoding {.proto3.} = object
  x {.pint, fieldNumber: 1.}: float32

discard Protobuf.encode(InvalidFloatEncoding())
