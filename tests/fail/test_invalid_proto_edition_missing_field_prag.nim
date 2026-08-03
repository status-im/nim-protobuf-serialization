import
  ../../protobuf_serialization

type
  #Mixed {.proto: 2023, implicit.} = object
  Mixed {.proto: 2023.} = object
    a {.fieldNumber: 1, pint.}: int32

discard Protobuf.encode(Mixed())
