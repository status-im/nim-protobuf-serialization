import ../../protobuf_serialization

type NegativeFieldNumber = object
  x {.fieldNumber: -1.}: bool

discard Protobuf.encode(NegativeFieldNumber())
