# Optional Fields

In protobuf, distinguishing between "field not set" and "field set to default value" can be important. This library provides two ways to handle optional fields: `Opt[T]` for proto3 and `PBOption` for proto2.

## The Problem with Default Values

In proto3, fields have implicit default values:

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:proto3_default_problem}}
```

When you decode a message, you can't tell if `count` was explicitly set to `0` or just not set at all.

## Using Opt[T] (Proto3 or Proto2)

For proto3, the recommended approach is to use `Opt[T]` from the [results](https://github.com/arnetheduck/nim-results) library (re-exported via `protobuf_serialization/pkg/results`). This wraps a value to make it explicitly optional:

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:proto3_opt_type}}
```

### Creating Optional Values

Use `Opt.some()` to create a value that is present, and `Opt.none()` to create a value that is absent:

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:proto3_opt_create}}
```

### Checking if a Value is Present

Use `isSome()` and `isNone()` to check presence:

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:proto3_opt_check}}
```

### Getting the Value

Use `get()` to retrieve the value:

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:proto3_opt_get}}
```

Use `valueOr()` to provide a default:

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:proto3_opt_valueor}}
```

## Using PBOption (Proto2)

For proto2, use [`PBOption`](../apidocs/protobuf_serialization/types.html#PBOption) to make fields explicitly optional:

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:proto2_pboption_type}}
```

### Creating Optional Values

Use `pbSome()` to create a value that is present, and `pbNone()` to create a value that is absent:

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:proto2_pboption_create}}
```

### Encoding and Decoding

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:proto2_pboption_encode_decode}}
```

### Getting the Value

Use `get` to retrieve the value, and `valueOr` to provide a default:

```nim
{{#shiftinclude auto:../../../examples/optional_fields.nim:proto2_pboption_valueor}}
```

## When to Use Each Approach

**Use `Opt[T]` when:**
- Working with proto3
- You need to distinguish "not set" from "set to default"
- Building APIs where presence matters

**Use `PBOption` when:**
- Working with proto2
- You need to distinguish "not set" from "set to default"

**Don't use either when:**
- Default values are acceptable
- You don't need presence tracking
- Performance is critical (adds overhead)

## Next Steps

- Learn about [importing .proto files](./import-proto.md)
- Explore [type extensions](./type-extensions.md) for custom serialization
