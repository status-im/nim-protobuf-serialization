import ../../protobuf_serialization

type NoIntEncoding = object
  x {.fieldNumber: 1.}: int32

discard Protobuf.encode(NoIntEncoding())
