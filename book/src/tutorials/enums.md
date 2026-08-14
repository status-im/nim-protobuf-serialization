# Enums

Protobuf enums map naturally to Nim enums. Support for enum fields is not part
of the default import—it lives in a separate module that you have to import
explicitly.

## Importing `std/enums`

The core `protobuf_serialization` module does not know how to serialize enum
fields. To use them, import `protobuf_serialization/std/enums`:

```nim
{{#shiftinclude auto:../../../examples/enums.nim:imports}}
```

Without this import, the compiler has no serialization handlers for your enum
type and the code will not compile.

Enum fields are annotated with the [`{.ext.}`](../apidocs/protobuf_serialization/types.html#ext.t)
pragma, because enum support is implemented as a type extension:

```nim
{{#shiftinclude auto:../../../examples/enums.nim:basic}}
```

Encoding and decoding then works like any other field:

```nim
{{#shiftinclude auto:../../../examples/enums.nim:basic_roundtrip}}
```

## The Zero-Value Requirement

In proto3, an enum must contain a constant that maps to `0`. If it does not,
compilation fails with a `{.fatal.}` error. In the example above, `Unknown`
satisfies this requirement because it is the first value and therefore has
ordinal `0`.

## Closed Enum Semantics

Nim enums are **closed**: a value of an enum type can only be one of the
constants defined for that type. There is no way to hold a `Status` whose value
is `3` when only `0`, `1`, and `2` are defined.

Because protobuf enums are mapped onto Nim enums, they inherit this closed
behavior. This is **not** conformant with proto3's open-enum semantics, where an
unknown value is preserved so it can be re-serialized unchanged. In `nim-protobuf-protobuf_serialization`, unknown
values are not stored at all and therefore cannot be serialized back.

If you need proto3-conformant behavior, use an `int32` field instead—see
[Preserving proto3-Compatible Semantics](#preserving-proto3-compatible-semantics)
below.

### Unknown Values

How an unknown value is handled on decode depends on the syntax:

**proto3**—the unknown value is dropped and the field keeps its zero value:

```nim
{{#shiftinclude auto:../../../examples/enums.nim:proto3_unknown}}
```

**proto2 with [`required`](../apidocs/protobuf_serialization/types.html#required.t)**—the unknown value is a decode error:

```nim
{{#shiftinclude auto:../../../examples/enums.nim:proto2_required}}
```

```nim
{{#shiftinclude auto:../../../examples/enums.nim:proto2_required_invalid}}
```

## Enums With Holes

Enum ordinals do not have to be contiguous, and they may be negative:

```nim
{{#shiftinclude auto:../../../examples/enums.nim:holes}}
```

## Optional Enums

In proto2, wrap an enum field in a [`PBOption`](../apidocs/protobuf_serialization/types.html#PBOption)
to distinguish "not set" from "set to the default value". Use `pbSome` and
`pbNone` to construct the values:

```nim
{{#shiftinclude auto:../../../examples/enums.nim:proto2_optional}}
```

```nim
{{#shiftinclude auto:../../../examples/enums.nim:proto2_optional_roundtrip}}
```

```admonish info
The `PBOption` parameter is the field's default *value*, not its type. Writing
`PBOption[default(Status)]` stores a full `Status` (the value type is derived
from the default), and falls back to `default(Status)` (that is, `Unknown`) when
the field is not set. So this reads as "either a `Status`, or not set with a
default of `Unknown`". Passing the type directly (`PBOption[Status]`) does not
compile, because the parameter expects a value. `pbNone` likewise takes the
default value, matching the field declaration.
```

## Repeated & Packed Enums

Repeated enum fields follow the same packing rules as other repeated numeric
fields (see [Repeated & Packed Fields](./repeated-packed.md)): proto2 defaults to
unpacked, proto3 defaults to packed, and the
[`{.packed.}`](../apidocs/protobuf_serialization/types.html#packed.t,bool) pragma
overrides the default:

```nim
{{#shiftinclude auto:../../../examples/enums.nim:repeated}}
```

Unknown entries in a repeated enum field are dropped; the valid entries are kept:

```nim
{{#shiftinclude auto:../../../examples/enums.nim:repeated_invalid}}
```

## Preserving proto3-Compatible Semantics

Because Nim enums are closed, they cannot preserve unknown values. If you need
the proto3-conformant behavior—where unknown values survive a decode/encode
round-trip—store the value as an `int32` field with the
[`{.pint.}`](../apidocs/protobuf_serialization/types.html#pint.t) pragma instead
of a Nim enum. Named values become plain constants:

```nim
{{#shiftinclude auto:../../../examples/enums.nim:int_rewrite}}
```

Now an unknown value is preserved rather than dropped:

```nim
{{#shiftinclude auto:../../../examples/enums.nim:int_rewrite_preserved}}
```

Compare this with the [proto3 unknown-value behavior](#unknown-values) of a Nim
enum, where the value `3` was dropped and replaced with the zero value.

## Next Steps

- Learn about [repeated and packed fields](./repeated-packed.md) for arrays
- Explore [optional fields](./optional-fields.md) with `PBOption`
