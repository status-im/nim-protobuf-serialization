# nim-protobuf-serialization

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)
![Github action](https://github.com/status-im/nim-protobuf-serialization/workflows/CI/badge.svg)

Protobuf implementation compatible with the [nim-serialization](https://github.com/status-im/nim-serialization) framework.

## Documentation

- [Quickstart Guide](https://status-im.github.io/nim-protobuf-serialization/quickstart.html)
- [API Reference](https://status-im.github.io/nim-protobuf-serialization/apidocs/theindex.html)
- [Contributor's Guide](https://status-im.github.io/nim-protobuf-serialization/contributing.html)
- [Report Issues](https://github.com/status-im/nim-protobuf-serialization/issues)

## Installation

Add to your `.nimble` file:

```nim
requires "protobuf_serialization"
```

Or install directly:

```bash
nimble install protobuf_serialization
```

## Basic Usage

```nim
import protobuf_serialization

# Define a protobuf message
type
  Person {.proto3.} = object
    name {.fieldNumber: 1.}: string
    age {.fieldNumber: 2, pint.}: int32
    email {.fieldNumber: 3.}: string

# Encode and decode
let person = Person(name: "Alice", age: 30, email: "alice@example.com")
let encoded = Protobuf.encode(person)
let decoded = Protobuf.decode(encoded, Person)

assert decoded == person
```

Both Protobuf 2 and Protobuf 3 are supported. You can also import `.proto` files directly at compile-time using `import_proto3`.

## License

Licensed and distributed under either of

- MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

- Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.
