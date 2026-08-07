# ANCHOR: all
import protobuf_serialization

type
  ValueKind {.pure.} = enum
    notSet
    intValue
    stringValue
    boolValue

  Value {.proto3, oneof.} = object
    case kind: ValueKind
    of ValueKind.notSet:
      discard
    of ValueKind.intValue:
      intValue {.fieldNumber: 10, sint.}: int32
    of ValueKind.stringValue:
      stringValue {.fieldNumber: 11.}: string
    of ValueKind.boolValue:
      boolValue {.fieldNumber: 12.}: bool

  Config {.proto3.} = object
    key {.fieldNumber: 1.}: string
    value {.oneof.}: Value

# Usage
let config1 = Config(
  key: "timeout",
  value: Value(kind: ValueKind.intValue, intValue: 30)
)

let config2 = Config(
  key: "name",
  value: Value(kind: ValueKind.stringValue, stringValue: "Alice")
)

let config3 = Config(
  key: "enabled",
  value: Value(kind: ValueKind.boolValue, boolValue: true)
)

# Encode and decode
let encoded1 = Protobuf.encode(config1)
let decoded1 = Protobuf.decode(encoded1, Config)
assert decoded1.key == "timeout"
assert decoded1.value.kind == ValueKind.intValue
assert decoded1.value.intValue == 30

echo "Oneof with different types example passed!"
# ANCHOR_END: all