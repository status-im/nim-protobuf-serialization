# Importing .proto Files

Instead of manually annotating Nim types, you can generate them directly from `.proto` files using the [`import_proto3`](../apidocs/protobuf_serialization/files/type_generator.html#import_proto3.t%2Cstatic[string]) template.

## Basic Usage

```nim
import protobuf_serialization/proto_parser

# Generate Nim types from a .proto file
import_proto3 "my_protocol.proto3"
```

This template reads the `.proto` file at compile time and generates equivalent Nim types.

## Example .proto File

**person.proto3**:
```proto
syntax = "proto3";

message Person {
  string name = 1;
  int32 age = 2;
  string email = 3;
}

message AddressBook {
  repeated Person people = 1;
}
```

**Nim code**:
```nim
{{#shiftinclude auto:../../../examples/import_proto_basic.nim:all}}
```

## Supported Features

The proto parser supports most proto3 features:

### Messages
```proto
message User {
  string username = 1;
  int32 score = 2;
}
```

### Enums
```proto
enum Status {
  UNKNOWN = 0;
  ACTIVE = 1;
  INACTIVE = 2;
}

message User {
  string name = 1;
  Status status = 2;
}
```

### Nested Messages
```proto
message Outer {
  message Inner {
    string value = 1;
  }
  Inner data = 1;
}
```

### Repeated Fields
```proto
message Numbers {
  repeated int32 values = 1;
  repeated string names = 2;
}
```

### Oneof
```proto
message Contact {
  oneof contact_info {
    string email = 1;
    string phone = 2;
    string address = 3;
  }
}
```

### Packages
```proto
package mypackage;

message Request {
  string query = 1;
}
```

## Field Type Mapping

The parser automatically maps proto types to appropriate Nim types with correct pragmas:

| Proto Type | Generated Nim Type | Pragma |
|-----------|-------------------|--------|
| `int32`, `int64` | `int32`, `int64` | `{.pint.}` |
| `uint32`, `uint64` | `uint32`, `uint64` | `{.pint.}` |
| `sint32`, `sint64` | `int32`, `int64` | `{.sint.}` |
| `fixed32`, `fixed64` | `uint32`, `uint64` | `{.fixed.}` |
| `sfixed32`, `sfixed64` | `int32`, `int64` | `{.fixed.}` |
| `float` | `float32` | - |
| `double` | `float64` | - |
| `bool` | `bool` | - |
| `string` | `string` | - |
| `bytes` | `seq[byte]` | - |

## Complete Example

**protocol.proto3**:
```proto
syntax = "proto3";

package example;

enum Priority {
  LOW = 0;
  MEDIUM = 1;
  HIGH = 2;
}

message Task {
  string id = 1;
  string title = 2;
  string description = 3;
  Priority priority = 4;
  repeated string tags = 5;
  bool completed = 6;
}

message TaskList {
  repeated Task tasks = 1;
  string owner = 2;
}
```

**Nim code**:
```nim
{{#shiftinclude auto:../../../examples/import_proto_complete.nim:all}}
```

## File Paths

The `.proto` file path is relative to the Nim source file:

```nim
# If your Nim file is in src/main.nim
# and proto file is in src/protocol.proto3
import_proto3 "protocol.proto3"

# Or use absolute/relative paths
import_proto3 "../protos/protocol.proto3"
```

## Services and RPCs

Services and RPCs are fully parsed from `.proto` files. The library provides a hook mechanism that allows you to generate custom code for services. This is useful for generating RPC client/server stubs.

The `import_proto3` template accepts an optional `protoHook` parameter that receives the parsed proto definitions and can generate additional Nim code. See the test suite for an example of generating service proc definitions and path constants: [tests/test_proto_file.nim](https://github.com/status-im/nim-protobuf-serialization/blob/master/tests/test_proto_file.nim).

For a real-world example of using this hook to generate gRPC client/server code, see [nim-grpc](https://github.com/nitely/nim-grpc/blob/e97aac4310ad18f852fbfffc32334b680c8c296d/src/grpc/protobuf.nim).

## Maps

Maps are supported and are mapped to repeated fields rather than Nim `Table` types. This is because protobuf spec allows repeated keys, which `Table` doesn't support. In the future, there may be a way to provide custom type mappings (proto-type → nim-type), but this requires a more general solution for any type.

## Other Limitations

- Custom options
- Extensions (proto2 feature)

## Next Steps

- Learn about [type extensions](./type-extensions.md) for custom serialization
- Read the [contributor's guide](../contributing.md)
