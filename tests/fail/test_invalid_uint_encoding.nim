import ../../protobuf_serialization

type InvalidUIntEncoding {.proto3.} = object
  x {.sint, fieldNumber: 1.}: uint32

discard Protobuf.encode(InvalidUIntEncoding())
