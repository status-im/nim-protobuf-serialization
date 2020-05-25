import ../../protobuf_serialization

type UnspecifiedUIntBits = object
  x {.pint, fieldNumber: 1.}: uint

discard Protobuf.encode(UnspecifiedUIntBits())
