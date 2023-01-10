import ../../protobuf_serialization

type ZeroFieldNumber  {.proto3.} = object
  x {.fieldNumber: 0.}: bool

discard Protobuf.encode(ZeroFieldNumber())
