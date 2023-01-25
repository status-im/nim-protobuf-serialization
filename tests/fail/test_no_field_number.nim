import ../../protobuf_serialization

type NoFieldNumber {.proto3.} = object
  x: bool

discard Protobuf.encode(NoFieldNumber())
