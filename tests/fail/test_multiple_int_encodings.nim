import ../../protobuf_serialization

type MultipleIntEncodings = object
  x {.pint, sint, fieldNumber: 1.}: int32

discard Protobuf.encode(MultipleIntEncodings())
