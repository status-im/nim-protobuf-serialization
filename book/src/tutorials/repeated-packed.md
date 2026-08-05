# Repeated & Packed Fields

Protobuf supports repeated fields (arrays/lists) with two encoding modes: unpacked and packed.

## Repeated Fields (Unpacked)

In proto2, repeated fields are encoded as separate entries for each element.

In proto3, [`packed`](../apidocs/protobuf_serialization/types.html#packed.t,bool) pragma with `false` value is used to mark fields as unpacked:

```nim
{{#shiftinclude auto:../../../examples/repeated_packed.nim:unpacked}}
```

### Example

```nim
{{#shiftinclude auto:../../../examples/repeated_packed.nim:usage_unpacked}}
```

The encoded bytes for the `values` field look like this:
```
08 0a 08 05 08 d8 04 08 c7 09
```
Each value has its own field tag (`08` for field 1, wire type 0 = varint).

## Packed Fields

Packed encoding is more efficient for scalar numeric types. All elements are encoded as a single length-delimited field. Use the [`packed`](../apidocs/protobuf_serialization/types.html#packed.t,bool) pragma with `true` value to enable it in `proto2`:

```nim
{{#shiftinclude auto:../../../examples/repeated_packed.nim:packed}}
```

### Benefits of Packed Encoding

- **Smaller size**: Single length prefix instead of one per element
- **Faster parsing**: Elements are contiguous in memory
- **Better for large arrays**: Especially beneficial for numeric data

### When to Use Packed

✅ **Use packed for:**
- Numeric arrays (int, uint, float, bool)
- Large sequences
- Performance-critical code

❌ **Don't use packed for:**
- String arrays (not supported)
- Message arrays (not supported)
- Small arrays (overhead may not be worth it)

### Example

```nim
{{#shiftinclude auto:../../../examples/repeated_packed.nim:usage_packed}}
```

The encoded bytes for the `values` field look like this:
```
0a 04 0a 05 d8 04
```
All values are grouped together after a single field tag (`0a` for field 1, wire type 2 = length-delimited) and a length prefix (`04` = 4 bytes).

## Proto2 vs Proto3

**Proto2**: Repeated fields are unpacked by default
```nim
type
  Message {.proto2.} = object
    values {.fieldNumber: 1.}: seq[int32]  # Unpacked by default
```

**Proto3**: Scalar numeric types are packed by default
```nim
type
  Message {.proto3.} = object
    values {.fieldNumber: 1.}: seq[int32]  # Packed by default
```

You can explicitly control this with the [`packed`](../apidocs/protobuf_serialization/types.html#packed.t,bool) pragma:

```nim
type
  Message {.proto3.} = object
    unpacked {.fieldNumber: 1, packed: false.}: seq[int32]
    packed {.fieldNumber: 2, packed: true.}: seq[int32]
```

## Empty Sequences

Empty sequences are omitted from the encoded output entirely. When decoded, they become empty sequences:

```nim
let empty = DataSet()
let encoded = Protobuf.encode(empty)
# encoded is empty - no bytes at all

let decoded = Protobuf.decode(encoded, DataSet)
assert decoded.temperatures.len == 0
assert decoded.labels.len == 0
```

## Next Steps

- Learn about [oneof fields](./oneof.md) for union types
- Explore [optional fields](./optional-fields.md) with `PBOption`
