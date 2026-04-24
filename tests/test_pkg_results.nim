# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2, results

import
  ../protobuf_serialization,
  ../protobuf_serialization/pkg/results

type
  OneOption {.proto2.} = object
    a {.fieldNumber: 1, pint.}: Opt[int32]

  FullOfDefaults {.proto2.} = object
    a {.fieldNumber: 2.}: Opt[string]
    b {.fieldNumber: 3.}: Opt[OneOption]

suite "Test results Opt[T]":
  test "Handles default":
    var fod: FullOfDefaults = FullOfDefaults(b: Opt.some(OneOption(a: Opt.some(123'i32))))
    check:
      Protobuf.decode(Protobuf.encode(fod), FullOfDefaults).a.isNone()
      Protobuf.decode(Protobuf.encode(fod), FullOfDefaults).b.isSome()
      Protobuf.decode(Protobuf.encode(fod), FullOfDefaults).b.get().a.get() == 123'i32
