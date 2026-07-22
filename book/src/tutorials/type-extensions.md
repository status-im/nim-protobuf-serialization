# Type Extensions

Type extensions allow you to define custom serialization logic for types that aren't directly annotated with protobuf pragmas. This is useful when you want to serialize external types or types with custom encoding requirements.

## When to Use Type Extensions

Use type extensions when:
- You need to serialize types from external libraries
- You want custom encoding logic (e.g., compression, encryption)
- You're working with types that can't be annotated directly
- You need to serialize wrapper types

## Basic Structure

A type extension consists of three procedures:

1. `computeFieldSize`—calculates the encoded size
2. `writeField`—encodes the value
3. `readFieldInto`—decodes the value

## Simple Example

Let's create a custom type and make it serializable:

```nim
{{#shiftinclude auto:../../../examples/type_extensions.nim:custom_type}}
```

Now we define a message that uses this custom type:

```nim
{{#shiftinclude auto:../../../examples/type_extensions.nim:message}}
```

To make `IntWrapper` serializable, we need to implement the three required procedures:

```nim
{{#shiftinclude auto:../../../examples/type_extensions.nim:extension}}
```

## Using the Extension

Now you can use the custom type in your protobuf messages:

```nim
{{#shiftinclude auto:../../../examples/type_extensions.nim:usage}}
```

## Extension with Sequences

The `extensionDefaults` macro can generate default handlers for sequences:

```nim
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
```

## Packed Extensions

For numeric types, you can enable packed encoding:

```nim
type
  Int32Wrapper = object
    value: int32

# Enable packed encoding
Protobuf.extensionDefaults(Int32Wrapper, pint32, packed = true)

func computeFieldSize(
    field: int,
    value: Int32Wrapper,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  computeFieldSize(field, value.value, pint32, skipDefault)

proc writeField(
    stream: OutputStream,
    field: int,
    value: Int32Wrapper,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  writeField(stream, field, value.value, pint32, skipDefault)

proc readFieldInto(
    stream: InputStream,
    value: var Int32Wrapper,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  readFieldInto(stream, value.value, header, pint32)
```

## Complete Example

Here's a complete example with a custom timestamp type:

```nim
import protobuf_serialization
import times

# Custom timestamp type
type
  Timestamp = object
    seconds: int64
    nanos: int32

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
  computeFieldSize(field, value.seconds, pint64, skipDefault) +
  computeFieldSize(field, value.nanos, sint32, skipDefault)

proc writeField(
    stream: OutputStream,
    field: int,
    value: Timestamp,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  writeField(stream, field, value.seconds, pint64, skipDefault)
  writeField(stream, field, value.nanos, sint32, skipDefault)

proc readFieldInto(
    stream: InputStream,
    value: var Timestamp,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  readFieldInto(stream, value.seconds, header, pint64)
  readFieldInto(stream, value.nanos, header, sint32)

# Usage
let event = Event(
  name: "UserLogin",
  timestamp: Timestamp(seconds: 1234567890'i64, nanos: 500000000'i32)
)

let encoded = Protobuf.encode(event)
let decoded = Protobuf.decode(encoded, Event)

assert decoded.timestamp.seconds == 1234567890
assert decoded.timestamp.nanos == 500000000
```

## Key Points

- Mark fields using extensions with `{.ext.}` pragma
- The extended type itself should NOT be annotated with `{.proto2.}` or `{.proto3.}`
- Use [`extensionDefaults`](../apidocs/protobuf_serialization/extension.html#extensionDefaults.t,typeProtobuf,type,typeSomeProto) to generate default sequence handlers
- Implement all three procedures: `computeFieldSize`, `writeField`, `readFieldInto`
- Extensions work with both single values and sequences

## Next Steps

- Read the [contributor's guide](../contributing.md) to learn how to contribute to the library
