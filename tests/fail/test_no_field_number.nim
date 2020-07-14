import ../../protobuf_serialization

type NoFieldNumber = object
  x: bool

discard Protobuf.encode(NoFieldNumber())
