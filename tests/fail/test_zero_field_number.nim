import ../../protobuf_serialization

type ZeroFieldNumber = object
  x {.fieldNumber: 0.}: bool

discard Protobuf.encode(ZeroFieldNumber())
