import
  ../../protobuf_serialization,
  ../../protobuf_serialization/pkg/results

type
  FullOfDefaults {.proto3.} = object
    #a {.fieldNumber: 1.}: Opt[string]
    a {.fieldNumber: 1.}: Opt[Opt[string]]

discard Protobuf.encode(FullOfDefaults())
