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

The [`extensionDefaults`](../apidocs/protobuf_serialization/extension.html#extensionDefaults.t,typeProtobuf,type,typeSomeProto) macro can generate default handlers for sequences:

```nim
{{#shiftinclude auto:../../../examples/type_extensions_seq.nim:all}}
```

## Complete Example

Here's a complete example with a custom timestamp type:

```nim
{{#shiftinclude auto:../../../examples/type_extensions_complete.nim:all}}
```

## Key Points

- Mark fields using extensions with `{.ext.}` pragma
- The extended type itself should NOT be annotated with `{.proto2.}` or `{.proto3.}`
- Use [`extensionDefaults`](../apidocs/protobuf_serialization/extension.html#extensionDefaults.t,typeProtobuf,type,typeSomeProto) to generate default sequence handlers
- Implement all three procedures: `computeFieldSize`, `writeField`, `readFieldInto`
- Extensions work with both single values and sequences

## Next Steps

- Read the [contributor's guide](../contributing.md) to learn how to contribute to the library