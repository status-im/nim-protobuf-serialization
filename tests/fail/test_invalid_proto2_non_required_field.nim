import ../../protobuf_serialization

type
  MissingRequired {.proto2.} = object
    #a {.fieldNumber: 1, required, pint.}: int32
    a {.fieldNumber: 1, pint.}: int32

discard Protobuf.encode(MissingRequired())
