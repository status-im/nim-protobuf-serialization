import
  ../../protobuf_serialization,
  ../../protobuf_serialization/pkg/results

type NestedOpt {.proto2.} = object
  a {.fieldNumber: 1.}: Opt[Opt[string]]

discard Protobuf.encode(NestedOpt(a: Opt.some(Opt.some("abc"))))
