# ANCHOR: all
import protobuf_serialization

# ANCHOR: required
# 1. required pragma
type
  Message1 {.proto2.} = object
    id {.fieldNumber: 1, required, pint.}: int32
# ANCHOR_END: required

# ANCHOR: seq
# 2. Repeated field (seq)
type
  Message2 {.proto2.} = object
    tags {.fieldNumber: 1.}: seq[string]
# ANCHOR_END: seq

# ANCHOR: pboption
# 3. PBOption
type
  Message3 {.proto2.} = object
    name {.fieldNumber: 1.}: PBOption[default(string)]
# ANCHOR_END: pboption

# ANCHOR: ext
# 4. Extension type
type
  MyCustomType = object
    value: int32

Protobuf.extensionDefaults(MyCustomType, pint32)

func computeFieldSize(
    field: int,
    value: MyCustomType,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  computeFieldSize(field, value.value, pint32, skipDefault)

proc writeField(
    stream: OutputStream,
    field: int,
    value: MyCustomType,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  writeField(stream, field, value.value, pint32, skipDefault)

proc readFieldInto(
    stream: InputStream,
    value: var MyCustomType,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  readFieldInto(stream, value.value, header, pint32)

type
  Message4 {.proto2.} = object
    data {.fieldNumber: 1, required, ext.}: MyCustomType
# ANCHOR_END: ext

let msg1 = Message1(id: 42)
let encoded1 = Protobuf.encode(msg1)
let decoded1 = Protobuf.decode(encoded1, Message1)
assert decoded1 == msg1

let msg2 = Message2(tags: @["tag1", "tag2"])
let encoded2 = Protobuf.encode(msg2)
let decoded2 = Protobuf.decode(encoded2, Message2)
assert decoded2 == msg2

let msg3 = Message3(name: pbSome("Alice"))
let encoded3 = Protobuf.encode(msg3)
let decoded3 = Protobuf.decode(encoded3, Message3)
assert decoded3.name.get == "Alice"

let msg4 = Message4(data: MyCustomType(value: 100))
let encoded4 = Protobuf.encode(msg4)
let decoded4 = Protobuf.decode(encoded4, Message4)
assert decoded4.data.value == 100

echo "Proto2 required fields example passed!"
# ANCHOR_END: all
