import ../../protobuf_serialization

type MultipleUIntEncodings = object
  x {.pint, fixed, fieldNumber: 1.}: uint32

discard Protobuf.encode(MultipleUIntEncodings())
