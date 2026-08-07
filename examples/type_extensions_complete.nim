# ANCHOR: all
import protobuf_serialization

# Custom timestamp type
type
  Timestamp = object
    seconds: int64

# Message using the custom type
type
  Event {.proto3.} = object
    name {.fieldNumber: 1.}: string
    timestamp {.fieldNumber: 2, ext.}: Timestamp

# Type extension for Timestamp
Protobuf.extensionDefaults(Timestamp, pint64, defaultSeq = false)

func computeFieldSize(
    field: int,
    value: Timestamp,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  computeFieldSize(field, value.seconds, pint64, skipDefault)

proc writeField(
    stream: OutputStream,
    field: int,
    value: Timestamp,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  writeField(stream, field, value.seconds, pint64, skipDefault)

proc readFieldInto(
    stream: InputStream,
    value: var Timestamp,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  readFieldInto(stream, value.seconds, header, pint64)

# Usage
let event = Event(
  name: "UserLogin",
  timestamp: Timestamp(seconds: 1234567890'i64)
)

let encoded = Protobuf.encode(event)
let decoded = Protobuf.decode(encoded, Event)

assert decoded.timestamp.seconds == 1234567890

echo "Complete type extension example passed!"
# ANCHOR_END: all