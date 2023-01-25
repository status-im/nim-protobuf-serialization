import ../../protobuf_serialization

type NoIntEncoding {.proto3.} = object
  x {.fieldNumber: 1.}: int32

discard Protobuf.encode(NoIntEncoding())
