# Annotating Objects

To make your Nim types protobuf-serializable, you need to annotate them with pragmas that define the protobuf schema.

## Message Types

Every protobuf message must be annotated with either [`{.proto2.}`](../apidocs/protobuf_serialization/types.html#proto2.t) or [`{.proto3.}`](../apidocs/protobuf_serialization/types.html#proto3.t):

```nim
type
  MyMessage {.proto3.} = object
    # fields here
```

This corresponds to the `syntax` declaration in `.proto` files:

```proto
syntax = "proto3";

message MyMessage {
  // fields here
}
```

## Field Numbers

Every field must have a unique field number using the [`{.fieldNumber: N.}`](../apidocs/protobuf_serialization/types.html#fieldNumber.t,int) pragma:

```nim
{{#shiftinclude auto:../../../examples/annotating_objects.nim:basic}}
```

Field numbers are permanent—once assigned, they should never change for a given field.

## Scalar Types

Protobuf supports several scalar types. Here's how they map to Nim types:

| Protobuf Type | Nim Type | Pragma | Notes |
|--------------|----------|--------|-------|
| `int32`, `int64` | `int32`, `int64` | `{.pint.}` | Varint-encoded (inefficient for negative values) |
| `sint32`, `sint64` | `int32`, `int64` | `{.sint.}` | Zig-zag encoded (efficient for negative values) |
| `uint32`, `uint64` | `uint32`, `uint64` | `{.pint.}` | Varint-encoded |
| `fixed32`, `fixed64` | `uint32`, `uint64` | `{.fixed.}` | Fixed-width, always 4 or 8 bytes |
| `sfixed32`, `sfixed64` | `int32`, `int64` | `{.fixed.}` | Fixed-width signed |
| `float` | `float32` | - | 32-bit floating point |
| `double` | `float64` | - | 64-bit floating point |
| `bool` | `bool` | - | Boolean value |
| `string` | `string` | - | UTF-8 encoded string |
| `bytes` | `seq[byte]` | - | Arbitrary byte sequence |

### Integer Encoding Strategies

Choose the right encoding for your integers:

**[`pint`](../apidocs/protobuf_serialization/types.html#pint.t)** (p stands for "plain")—uses standard varint encoding. Best for positive values or small negative values
```nim
{{#shiftinclude auto:../../../examples/annotating_objects.nim:pint}}
```

**[`sint`](../apidocs/protobuf_serialization/types.html#sint.t)** (s stands for "signed")—uses zig-zag encoding. Best for negative values
```nim
{{#shiftinclude auto:../../../examples/annotating_objects.nim:sint}}
```

**[`fixed`](../apidocs/protobuf_serialization/types.html#fixed.t)**: Best for large values or when size predictability matters
```nim
{{#shiftinclude auto:../../../examples/annotating_objects.nim:fixed}}
```

## Nested Messages

You can use other protobuf messages as field types:

```nim
{{#shiftinclude auto:../../../examples/annotating_objects.nim:nested}}
```

## Proto2 vs Proto3 Differences

### Required Fields (Proto2 only)

In proto2, every field must be explicitly marked as [`required`](../apidocs/protobuf_serialization/types.html#required.t), be a repeated field (`seq`), be a [`PBOption`](../apidocs/protobuf_serialization/types.html#PBOption), or be an extension type:

**1. [`required`](../apidocs/protobuf_serialization/types.html#required.t) pragma** — the field must be present in the encoded message:

```nim
{{#shiftinclude auto:../../../examples/proto2_required.nim:required}}
```

**2. Repeated field (`seq`)** — repeated fields are always allowed without `required`:

```nim
{{#shiftinclude auto:../../../examples/proto2_required.nim:seq}}
```

**3. [`PBOption`](../apidocs/protobuf_serialization/types.html#PBOption)** — explicitly optional field that can be absent:

```nim
{{#shiftinclude auto:../../../examples/proto2_required.nim:pboption}}
```

**4. Extension type ([`ext`](../apidocs/protobuf_serialization/types.html#ext.t))** — a custom type with user-defined serialization logic:

```nim
{{#shiftinclude auto:../../../examples/proto2_required.nim:ext}}
```

## Complete Example

Here's a complete example with various field types:

```nim
{{#shiftinclude auto:../../../examples/annotating_objects.nim:all}}
```

## Next Steps

- Learn about [repeated and packed fields](./repeated-packed.md) for arrays
- Explore [oneof fields](./oneof.md) for union types
