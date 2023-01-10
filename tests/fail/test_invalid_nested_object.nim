import ../../protobuf_serialization

type
  X {.proto3.} = object
    y {.pint, sint, fieldNumber: 1.}: int32

  A {.proto3.} = object
    b {.fieldNumber: 1.}: X

discard Protobuf.encode(A())
