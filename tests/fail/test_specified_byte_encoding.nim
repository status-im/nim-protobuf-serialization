import ../../protobuf_serialization

type SpecifiedByteEncoding = object
  x {.pint, fieldNumber: 1.}: uint8

discard Protobuf.encode(SpecifiedByteEncoding())
