import ../../protobuf_serialization

type
  #Required {.proto2.} = object
  Required = object
    a {.fieldNumber: 1, pint.}: PBOption[2'i32]

  FullOfDefaults {.proto2.} = object
    b {.fieldNumber: 2.}: PBOption[default(Required)]

discard Protobuf.encode(FullOfDefaults())
