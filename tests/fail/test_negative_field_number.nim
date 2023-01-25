import ../../protobuf_serialization

type NegativeFieldNumber {.proto3.} = object
  x {.fieldNumber: -1.}: bool

discard Protobuf.encode(NegativeFieldNumber())
