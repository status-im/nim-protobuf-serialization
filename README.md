# nim-protobuf-serialization

[![Build Status (Travis)](https://img.shields.io/travis/status-im/nim-protobuf-serialization/master.svg?label=Linux%20/%20macOS "Linux/macOS build status (Travis)")](https://travis-ci.org/status-im/nim-protobuf-serialization)
[![Windows build status (Appveyor)](https://img.shields.io/appveyor/ci/nimbus/nim-protobuf-serialization/master.svg?label=Windows "Windows build status (Appveyor)")](https://ci.appveyor.com/project/nimbus/nim-protobuf-serialization)
[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)
![Github action](https://github.com/status-im/nim-protobuf-serialization/workflows/nim-protobuf-serialization%20CI/badge.svg)

Protobuf implementation compatible with the [nim-serialization](https://github.com/status-im/nim-serialization) framework.

## Usage

Due to the complexities of Protobuf, and the fact this library makes zero assumptions about encodings, extensive pragmas are required.

Both Protobuf 2 and Protobuf 3 semantics are supported. When declaring an object, add either the `protobuf2` or `protobuf3` pragma to declare which to use. When using Protobuf 3, a `import_proto3` macro is available. Taking in a file path, it can directly parse a Protobuf 3 spec file and generate the matching Nim types:

**my_protocol.proto3**:

```proto3
message ExampleMsg {
  int32 a = 1;
  float b = 2;
}
```

**nim_module.nim**:

```nim
import_proto3 "my_protocol.proto3"

#[
Generated:
type ExampleMsg {.protobuf3.} = object
  a {.pint, fieldNumber: 1.}: int32
  b {.pfloat32, fieldNumber: 2.}: float32
]#

let x = ExampleMsg(a: 10, b: 20.0)
let encoded = Protobuf.encode(x)
...
let decoded = Protobuf.decode(encoded, ExampleMsg)
```

Both Protobuf 2 and Protobuf 3 objects have the following properties:

- Every field requires the `fieldNumber` pragma, which takes in an integer of what field number to encode that field with.
- Every int/uint must have its bits explicitly specified. As the Nim compiler is unable to distinguish between a float with its bits explicitly specified and a float, `pfloat32` or `pfloat64` is required.
- int/uint fields require their encoding to be specified. `pint` is valid for both, and uses VarInt encoding, which only uses the amount of bytes it needs. `fixed` is also valid for both, and uses the full amount of bytes the number uses, instead of stripping unused bytes. This has performance advantages for large numbers. Finally, `sint` uses zig-zagged VarInt encoding, which is recommended for numbers which are frequently negative, and is only valid for ints.

Protobuf 2 has the additional properties:

- A `required` pragma is enabled, matching the syntax of Protobuf 2's required keyword.
- Every primitive value, such as a number or string, must have the `required` pragma or be a `PBOption`. `PBOption`s are a generic type instantiated with the default value for that field. They serve as regular Options, except when they're none, they still return a value when get is called (the default value). `PBOption`s can be constructed using `pbSome(PBOption[T], value)`.

Here is an example demonstrating how the various pragmas can be combined:

```nim
type
  X {.protobuf3.} = object
    a {.pint, fieldNumber: 1.}: int32
    b {.pfloat32, fieldNumber: 2.}: float32

  Y {.protobuf2.} = object
    a {.fieldNumber: 1.}: seq[string]
    b {.pint, fieldNumber: 2.}: PBOption[int32(2)]
    c {.required, sint, fieldNumber: 3.}: int32
```

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.
