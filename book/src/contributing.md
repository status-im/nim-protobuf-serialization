# Contributing

Thank you for your interest in contributing to nim-protobuf-serialization! This guide will help you get started.

## Getting the Source

```bash
git clone https://github.com/status-im/nim-protobuf-serialization.git
cd nim-protobuf-serialization
```

## Prerequisites

- [Nim](https://nim-lang.org/) >= 1.6.20
- [mdBook](https://rust-lang.github.io/mdBook/) (for building documentation)

## Project Structure

```
├── protobuf_serialization/       # Library source code
│   ├── codec.nim                 # Core codec implementation
│   ├── extension.nim             # Type extension support
│   ├── format.nim                # Format definition
│   ├── internal.nim              # Internal utilities
│   ├── reader.nim                # Decoding logic
│   ├── writer.nim                # Encoding logic
│   ├── sizer.nim                 # Size computation
│   ├── types.nim                 # Type definitions and pragmas
│   ├── proto_parser.nim          # Proto file parser entry
│   └── files/
│       ├── type_generator.nim    # Code generation from .proto files
│       └── proto_parser.nim      # PEG-based proto parser
├── tests/                        # Test suite
├── book/                         # mdBook documentation source
│   ├── book.toml                 # mdBook configuration
│   └── src/                      # Markdown source files
└── docs/                         # Generated documentation (output)
```

## Running Tests

Run the full test suite:

```bash
nimble test
```

This runs tests with multiple configurations:
- `--threads:off` and `--threads:on`
- `-d:release` and `-d:danger`
- Address sanitizer (on Linux/amd64 with Nim >= 2.2)

The test suite also includes compile-fail tests in `tests/fail/`. These are negative tests that verify the library correctly rejects invalid code—for example, using proto2-only features in proto3, or missing required pragmas. The test suite automatically attempts to compile each file in this directory and expects compilation to fail.

### Running Individual Tests

```bash
nim c -r tests/test_objects.nim
nim c -r tests/test_oneof.nim
nim c -r tests/test_extension.nim
```

### Conformance Tests

Run the official protobuf conformance test suite:

```bash
nimble conformance_test
```

## Building Documentation

Build the book documentation:

```bash
nimble book
```

Generate API documentation:

```bash
nimble apidocs
```

To preview the book locally with live reload:

```bash
mdbook serve book
```

## Code Style

- Follow the [Status Nim Style Guide](https://status-im.github.io/nim-style-guide/)
- Use `{.push raises: [], gcsafe.}` at the top of modules

## Adding Tests

Tests live in the `tests/` directory. Each test file should:

1. Import `unittest2` and the library
2. Define test types with protobuf annotations
3. Use the `roundtrip` helper from `tests/utils.nim` for encode/decode verification

```nim
import unittest2
import ../protobuf_serialization
import ./utils

type
  MyType {.proto3.} = object
    field {.fieldNumber: 1.}: string

suite "My feature":
  test "roundtrip":
    roundtrip(MyType(field: "hello"), "0a0568656c6c6f")
```

## Submitting Changes

1. Create a feature branch from `master`
2. Make your changes
3. Run the test suite: `nimble test` and build docs: `nimble docs`
4. Commit with a clear message
5. Open a pull request

## Reporting Issues

Open an issue on [GitHub](https://github.com/status-im/nim-protobuf-serialization/issues) with:
- A clear description of the problem
- Steps to reproduce (if applicable)
- Nim version and platform information
- Minimal code example (if applicable)

## License

By contributing, you agree that your contributions will be licensed under the same terms as the project (MIT / Apache 2.0, at your option).
