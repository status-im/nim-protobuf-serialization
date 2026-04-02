# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2

import ../protobuf_serialization

type
  Float2Object {.proto2.} = object
    a {.fieldNumber: 1.}: PBOption[1'f64]

  Float3Object {.proto3.} = object
    a {.fieldNumber: 1.}: float32

suite "Test Fixed Encoding/Decoding":
  test "Can encode/decode floats wrapped in an object":
    check:
      Protobuf.decode(
        Protobuf.encode(Float2Object(a: pbSome(PBOption[1'f64], 2.39'f64))),
        Float2Object
      ).a.get() == 2.39'f64

      Protobuf.decode(
        Protobuf.encode(Float3Object(a: 5.64'f32)),
        Float3Object
      ).a == 5.64'f32
