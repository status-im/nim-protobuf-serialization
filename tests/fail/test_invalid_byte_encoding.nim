import ../../protobuf_serialization

type InvalidByteEncoding = object
  x {.sint, fieldNumber: 1.}: uint8

discard Protobuf.encode(InvalidByteEncoding())
