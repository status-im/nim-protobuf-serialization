import ../../protobuf_serialization

type NoUIntEncoding = object
  x {.fieldNumber: 1.}: uint32

discard Protobuf.encode(NoUIntEncoding())
