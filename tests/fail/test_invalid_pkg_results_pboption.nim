import
  ../../protobuf_serialization,
  ../../protobuf_serialization/pkg/results

type
  FullOfDefaults {.proto2.} = object
    #a {.fieldNumber: 1.}: Opt[string]
    a {.fieldNumber: 1.}: Opt[PBOption[default(string)]]

discard Protobuf.encode(FullOfDefaults())
