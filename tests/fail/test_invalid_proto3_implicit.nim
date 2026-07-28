import ../../protobuf_serialization

type
  Invalid {.proto3.} = object
    a {.fieldNumber: 1, implicit.}: string

discard Protobuf.encode(Invalid())
