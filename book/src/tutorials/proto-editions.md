# Proto Editions

Protobuf *editions* are the successor to the proto2/proto3 split. Instead of
picking a syntax for the whole file, an edition (identified by a year, such as
2023) defines a set of default behaviors, and individual features—like field
presence—are configured per field. The goal is smoother, incremental evolution
of the format while preserving backward compatibility.

`nim-protobuf-serialization` exposes editions through the `{.proto.}` pragma.

## The `{.proto.}` Pragma

Annotate a message with
[`{.proto.}`](../apidocs/protobuf_serialization/types.html#proto.t,int) instead of
[`{.proto2.}`](../apidocs/protobuf_serialization/types.html#proto2.t) or
[`{.proto3.}`](../apidocs/protobuf_serialization/types.html#proto3.t):

```nim
{{#shiftinclude auto:../../../examples/proto_editions.nim:mixed}}
```

Unlike proto2 and proto3, `{.proto.}` lets you choose *presence* for each field:

- **[`PBExplicit`](../apidocs/protobuf_serialization/types.html#PBExplicit)**—explicit presence: the field can distinguish "not set" from
  "set to the default value" (this is an alias of
  [`PBOption`](../apidocs/protobuf_serialization/types.html#PBOption)).
- **[`required`](../apidocs/protobuf_serialization/types.html#required.t)**—the
  field must be present in the encoded message.
- **[`implicit`](../apidocs/protobuf_serialization/types.html#implicit.t)**—no presence tracking: the field behaves like a proto3 scalar,
  where the zero value is indistinguishable from "not set".

Every field in a `{.proto.}` message must be exactly one of `implicit`,
`required`, `PBExplicit`, or a repeated field (`seq[T]`).

Encoding and decoding work as usual:

```nim
{{#shiftinclude auto:../../../examples/proto_editions.nim:mixed_roundtrip}}
```

A `required` field that is missing from the encoded message is a decode error:

```nim
{{#shiftinclude auto:../../../examples/proto_editions.nim:required_missing}}
```

## Implicit by Default

Adding `implicit` at the type level makes fields implicit by default, so they no
longer need a per-field presence pragma (except `required`):

```nim
{{#shiftinclude auto:../../../examples/proto_editions.nim:implicit_default}}
```

## The Edition Year

The `edition` parameter selects the protobuf edition the type conforms to. It
must be one of the supported editions—**2023**, **2024**, or **2026**—and bare
`{.proto.}` defaults to **2023**:

```nim
{{#shiftinclude auto:../../../examples/proto_editions.nim:edition_year}}
```

```admonish info
The edition year is validated at compile time (an unsupported year fails to
compile), but it does **not** currently change the wire format. The behavioral
differences between editions live in `.proto` file parsing, which is not yet
supported. As a result, `{.proto: 2023.}`, `{.proto: 2024.}`, and
`{.proto: 2026.}` serialize identically today:
```

```nim
{{#shiftinclude auto:../../../examples/proto_editions.nim:edition_identical}}
```

## Next Steps

- Learn about [optional fields](./optional-fields.md) with `PBOption`
- Read the [annotating objects](./annotating-objects.md) tutorial for proto2 and
  proto3 basics
