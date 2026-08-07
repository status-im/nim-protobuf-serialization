# ANCHOR: all
import protobuf_serialization

type
  CustomType = object
    value: string

# Generate defaults for seq[CustomType]
Protobuf.extensionDefaults(CustomType, pstring, defaultSeq = true)

func computeFieldSize(
    field: int,
    value: CustomType,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  computeFieldSize(field, value.value, pstring, skipDefault)

proc writeField(
    stream: OutputStream,
    field: int,
    value: CustomType,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  writeField(stream, field, value.value, pstring, skipDefault)

proc readFieldInto(
    stream: InputStream,
    value: var CustomType,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  readFieldInto(stream, value.value, header, pstring)

# Now you can use seq[CustomType]
type
  Container {.proto3.} = object
    items {.fieldNumber: 1, ext.}: seq[CustomType]

let container = Container(
  items: @[
    CustomType(value: "first"),
    CustomType(value: "second"),
    CustomType(value: "third")
  ]
)

let encoded = Protobuf.encode(container)
let decoded = Protobuf.decode(encoded, Container)

assert decoded.items.len == 3
assert decoded.items[0].value == "first"
assert decoded.items[1].value == "second"
assert decoded.items[2].value == "third"

echo "Extension with sequences example passed!"
# ANCHOR_END: all