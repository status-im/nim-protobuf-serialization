import ../../protobuf_serialization

type
  Invalid {.proto2.} = object
    a {.fieldNumber: 1, implicit.}: seq[string]

discard Protobuf.encode(Invalid())
