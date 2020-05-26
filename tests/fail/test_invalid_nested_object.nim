import ../../protobuf_serialization

type
  X = object
    y {.pint, sint, fieldNumber: 1.}: int32

  A = object
    b {.fieldNumber: 1.}: X

discard Protobuf.encode(A())
