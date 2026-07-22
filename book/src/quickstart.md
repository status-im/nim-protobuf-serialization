# Quickstart

**nim-protobuf-serialization** is a Nim library that helps you serialize your Nim objects to Protobuf 2 or 3.

- [Repository →](https://github.com/status-im/nim-protobuf-serialization)
- [API Index →](./apidocs/theindex.html)
- [Issues →](https://github.com/status-in/nim-protobuf-serialization/issues)
- [Contributor's Guide →](./contributing.html)

## Installation

Add the dependency to your `.nimble` file:

```nim
requires "protobuf_serialization"
```

Or install directly:

```bash
nimble install protobuf_serialization
```

## Basic Usage

### 1. Define Your Types

Annotate your Nim types with protobuf pragmas:

```nim
{{#shiftinclude auto:../../examples/quickstart_basic.nim:import}}
{{#shiftinclude auto:../../examples/quickstart_basic.nim:type}}
```

### 2. Encode and Decode

Use `Protobuf.encode` and `Protobuf.decode` to serialize your objects:

```nim
{{#shiftinclude auto:../../examples/quickstart_basic.nim:usage}}
```

## Proto2 vs Proto3

Both Protobuf 2 and 3 semantics are supported. Add the `proto2` or `proto3` pragma to your object type:

```nim
{{#shiftinclude auto:../../examples/proto2_proto3.nim:proto2}}

{{#shiftinclude auto:../../examples/proto2_proto3.nim:proto3}}
```

```admonish info
The `required` pragma is only available in proto2. This reflects the Protocol Buffers specification: proto2 supports explicit `required`, `optional`, and `repeated` field modifiers, while proto3 removed the `required` keyword entirely. In proto3, all fields are implicitly optional with default values.
```

## Importing .proto Files

`.proto` files are Protocol Buffers schema definition files. They define the structure of your messages using a language-neutral, platform-neutral syntax. These files are commonly used to share message definitions across different programming languages and systems.

You might want to import `.proto` files when:

- Working with existing protobuf schemas from other projects or teams
- Ensuring compatibility with services that use standard `.proto` definitions
- Avoiding manual annotation of Nim types when a schema already exists

This library can generate Nim types directly from `.proto` files at **compile-time**:

```nim
import protobuf_serialization/proto_parser

# This generates Nim types from your .proto file at compile-time
import_proto3 "my_protocol.proto3"
```

```admonish info
The `import_proto3` macro reads and parses the `.proto` file during compilation, generating equivalent Nim types. This means there's no runtime overhead—the types are fully available as if you had written them manually in Nim.
```

## Building Documentation

Build the documentation site:

```bash
nimble docs
```

## Next Steps

- Learn how to [annotate your objects](./tutorials/annotating-objects.md) with protobuf pragmas
- Explore [repeated and packed fields](./tutorials/repeated-packed.md)
- Understand [oneof fields](./tutorials/oneof.md) for union types
- Handle [optional fields](./tutorials/optional-fields.md) with `PBOption`
- Import existing [.proto files](./tutorials/import-proto.md)
- Use [type extensions](./tutorials/type-extensions.md) for custom serialization
