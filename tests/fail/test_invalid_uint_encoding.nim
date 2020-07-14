import ../../protobuf_serialization

type InvalidUIntEncoding = object
  x {.sint, fieldNumber: 1.}: uint32

discard Protobuf.encode(InvalidUIntEncoding())
