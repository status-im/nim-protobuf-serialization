import ../../protobuf_serialization

type ReusedFieldNumber = object
  x {.fieldNumber: 1.}: bool
  y {.fieldNumber: 1.}: bool

discard Protobuf.encode(ReusedFieldNumber())
