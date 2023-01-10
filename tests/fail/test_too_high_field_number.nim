import ../../protobuf_serialization

# https://developers.google.com/protocol-buffers/docs/proto3#assigning_field_numbers
type TooHighFieldNumber {.proto3.} = object
  x {.fieldNumber: 536870912.}: bool

discard Protobuf.encode(TooHighFieldNumber())
