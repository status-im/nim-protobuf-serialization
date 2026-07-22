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
      intValue {.fieldNumber: 1, sint.}: int32
    of ValueKind.stringValue:
      stringValue {.fieldNumber: 2.}: string
    of ValueKind.boolValue:
      boolValue {.fieldNumber: 3.}: bool

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
```

## Oneof with Nested Messages

Oneof fields can contain nested message types:

```nim
type
  Error {.proto3.} = object
    code {.fieldNumber: 1.}: int32
    message {.fieldNumber: 2.}: string

  Success {.proto3.} = object
    data {.fieldNumber: 1.}: string

  ResultKind {.pure.} = enum
    notSet
    success
    error

  Result {.proto3, oneof.} = object
    case kind: ResultKind
    of ResultKind.notSet:
      discard
    of ResultKind.success:
      success {.fieldNumber: 1.}: Success
    of ResultKind.error:
      error {.fieldNumber: 2.}: Error

  Response {.proto3.} = object
    id {.fieldNumber: 1.}: string
    result {.oneof.}: Result

# Usage
let response = Response(
  id: "req-123",
  result: Result(
    kind: ResultKind.success,
    success: Success(data: "Operation completed")
  )
)
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
