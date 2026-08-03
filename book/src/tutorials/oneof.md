# Oneof Fields

The `oneof` field allows you to define a union type where only one field can be set at a time. This is useful for representing variant data.

## Defining Oneof Types

A oneof is defined as a separate object type with the [`{.oneof.}`](../apidocs/protobuf_serialization/types.html#oneof.t) pragma, using a Nim `case` object:

```nim
{{#shiftinclude auto:../../../examples/oneof.nim:type}}
```

## How Oneof Works

Only one field in a oneof can be set at a time. When you set a field, all other fields are cleared:

```nim
{{#shiftinclude auto:../../../examples/oneof.nim:usage}}
```

## Default State

When a oneof is not set, it defaults to the first value of the discriminator enum. In the example above, that's `ContactKind.notSet`, but you can name it whatever makes sense for your use case:

```nim
let person = Person(name: "Bob")
assert person.contact.kind == ContactKind.notSet

let encoded = Protobuf.encode(person)
let decoded = Protobuf.decode(encoded, Person)
assert decoded.contact.kind == ContactKind.notSet
```

## Oneof with Different Types

Oneof fields can have different types:

```nim
{{#shiftinclude auto:../../../examples/oneof_different_types.nim:all}}
```

## Oneof with Nested Messages

Oneof fields can contain nested message types:

```nim
{{#shiftinclude auto:../../../examples/oneof_nested.nim:all}}
```

## Handling Unknown Fields

When decoding, if a field number doesn't match any known oneof field, it's ignored:

```nim
# If the encoded data contains a field number that's not in the oneof,
# the oneof remains in its default state
let encoded = Protobuf.encode(person)
let decoded = Protobuf.decode(encoded, Person)
# Unknown fields are silently ignored
```

## Next Steps

- Learn about [optional fields](./optional-fields.md) with `PBOption`
- Explore [type extensions](./type-extensions.md) for custom serialization
