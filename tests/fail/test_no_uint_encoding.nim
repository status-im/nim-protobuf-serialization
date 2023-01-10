import ../../protobuf_serialization

type NoUIntEncoding {.proto3.} = object
  x {.fieldNumber: 1.}: uint32

discard Protobuf.encode(NoUIntEncoding())
