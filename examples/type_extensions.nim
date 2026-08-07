# ANCHOR: all
import protobuf_serialization

# ANCHOR: custom_type
# Custom wrapper type (not annotated with proto2/proto3)
type
  IntWrapper = object
    value: int32
# ANCHOR_END: custom_type

# ANCHOR: message
# Message that uses the custom type
type
  Container {.proto3.} = object
    name {.fieldNumber: 1.}: string
    data {.fieldNumber: 2, ext.}: IntWrapper
# ANCHOR_END: message

# ANCHOR: extension
# Define type extension for IntWrapper
Protobuf.extensionDefaults(IntWrapper, pint32, defaultSeq = true)

func computeFieldSize(
    field: int,
    value: IntWrapper,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  computeFieldSize(field, value.value, pint32, skipDefault)

proc writeField(
    stream: OutputStream,
    field: int,
    value: IntWrapper,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  writeField(stream, field, value.value, pint32, skipDefault)

proc readFieldInto(
    stream: InputStream,
    value: var IntWrapper,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  readFieldInto(stream, value.value, header, pint32)
# ANCHOR_END: extension

# ANCHOR: usage
let container = Container(
  name: "Test",
  data: IntWrapper(value: 42)
)

let encoded = Protobuf.encode(container)
let decoded = Protobuf.decode(encoded, Container)

assert decoded.data.value == 42
# ANCHOR_END: usage

echo "Type extensions example passed!"
# ANCHOR_END: all
