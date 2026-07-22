# ANCHOR: all
import protobuf_serialization

# ANCHOR: proto2
type
  MessageV2 {.proto2.} = object
    id {.fieldNumber: 1, required, pint.}: int32
    text {.fieldNumber: 2.}: seq[string]
# ANCHOR_END: proto2

# ANCHOR: proto3
type
  MessageV3 {.proto3.} = object
    id {.fieldNumber: 1, pint.}: int32
    text {.fieldNumber: 2.}: string
# ANCHOR_END: proto3

let msg2 = MessageV2(id: 42, text: @["hello"])
let encoded2 = Protobuf.encode(msg2)
let decoded2 = Protobuf.decode(encoded2, MessageV2)
assert decoded2 == msg2

let msg3 = MessageV3(id: 42, text: "hello")
let encoded3 = Protobuf.encode(msg3)
let decoded3 = Protobuf.decode(encoded3, MessageV3)
assert decoded3 == msg3

echo "Proto2/Proto3 example passed!"
# ANCHOR_END: all
