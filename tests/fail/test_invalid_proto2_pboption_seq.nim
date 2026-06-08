import ../../protobuf_serialization

type
  FullOfDefaults {.proto2.} = object
    a {.fieldNumber: 1.}: PBOption[default(seq[string])]

discard Protobuf.encode(FullOfDefaults())
