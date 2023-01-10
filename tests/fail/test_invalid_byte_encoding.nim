import ../../protobuf_serialization

type InvalidByteEncoding {.proto3.} = object
  x {.sint, fieldNumber: 1.}: uint8

discard Protobuf.encode(InvalidByteEncoding())
