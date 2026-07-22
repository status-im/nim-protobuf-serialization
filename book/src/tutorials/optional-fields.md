# Optional Fields

In protobuf, distinguishing between "field not set" and "field set to default value" can be important. The [`PBOption`](../apidocs/protobuf_serialization/types.html#PBOption) type provides explicit optional field support.

## The Problem with Default Values

In proto3, fields have implicit default values:

```nim
type
  Message {.proto3.} = object
    count {.fieldNumber: 1.}: int32  # Defaults to 0
    text {.fieldNumber: 2.}: string  # Defaults to ""
```

When you decode a message, you can't tell if `count` was explicitly set to `0` or just not set at all.

## Solutions for Proto3

Proto3 doesn't have a built-in way to distinguish "not set" from "set to default value" for scalar fields. You have three options:

### 1. Use Proto2 with PBOption

If you need to track field presence, use proto2 with [`PBOption`](../apidocs/protobuf_serialization/types.html#PBOption):

```nim
type
  Message {.proto2.} = object
    count {.fieldNumber: 1.}: PBOption[0'i32]
```

### 2. Use Wrapper Types

Wrap scalar values in message types, which can be `nil`:

```nim
type
  Int32Value {.proto3.} = object
    value {.fieldNumber: 1.}: int32

  Message {.proto3.} = object
    count {.fieldNumber: 1.}: Int32Value  # Can be nil
```

### 3. Use Oneof

Wrap the field in a oneof to track presence:

```nim
type
  CountKind {.pure.} = enum
    notSet
    value

  Count {.proto3, oneof.} = object
    case kind: CountKind
    of CountKind.notSet:
      discard
    of CountKind.value:
      value {.fieldNumber: 1.}: int32

  Message {.proto3.} = object
    count {.oneof.}: Count
```

## Using PBOption (Proto2 Only)

[`PBOption`](../apidocs/protobuf_serialization/types.html#PBOption) wraps a value to make it explicitly optional. Note that `PBOption` can only be used with proto2:

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:type}}
```

## Working with PBOption

### Creating Optional Values

Use [`pbSome`](../apidocs/protobuf_serialization/types.html#pbSome.t,untyped) to create a value that is present:

```nim
let user = Settings(
  username: "alice",
  theme: pbSome("dark"),
  fontSize: pbSome(14'i32),
  notifications: pbSome(true)
)
```

Use [`pbNone`](../apidocs/protobuf_serialization/types.html#pbNone.t,untyped) to create a value that is absent:

```nim
let user = Settings(
  username: "bob",
  theme: pbNone(default(string)),
  fontSize: pbNone(0'i32),
  notifications: pbNone(false)
)
```

### Checking if a Value is Present

Use [`isSome`](../apidocs/protobuf_serialization/types.html#isSome,PBOption) and [`isNone`](../apidocs/protobuf_serialization/types.html#isNone,PBOption) to check presence:

```nim
if user.fontSize.isSome:
  echo "Font size is set to: ", user.fontSize.get
else:
  echo "Font size is not set"
```

### Getting the Value

Use [`get`](../apidocs/protobuf_serialization/types.html#get,PBOption) to retrieve the value (raises if not set):

```nim
let fontSize = user.fontSize.get  # Returns the int32 value
```

Use [`valueOr`](../apidocs/protobuf_serialization/types.html#valueOr.t,PBOption,untyped) to provide a default:

```nim
let fontSize = user.fontSize.valueOr(12'i32)  # Returns 12 if not set
```

### Modifying the Value

Use [`mget`](../apidocs/protobuf_serialization/types.html#mget.t,PBOption) to get a mutable reference:

```nim
var user = Settings(username: "alice")
user.fontSize.mget = 30  # Sets the value and marks it as present
```

## Complete Example

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:usage}}
```

## When to Use PBOption

✅ **Use PBOption when:**
- You need to distinguish "not set" from "set to default"
- Working with proto2 optional fields
- Building APIs where presence matters

❌ **Don't use PBOption when:**
- Default values are acceptable
- You're using proto3 and don't need presence tracking
- Performance is critical (adds overhead)

## Next Steps

- Learn about [importing .proto files](./import-proto.md)
- Explore [type extensions](./type-extensions.md) for custom serialization
