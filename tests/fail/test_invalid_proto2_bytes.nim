import ../../protobuf_serialization

type
  Bytes {.proto2.} = object
    #a {.fieldNumber: 1, required.}: seq[byte]
    a {.fieldNumber: 1.}: seq[byte]

discard Protobuf.encode(Bytes())
