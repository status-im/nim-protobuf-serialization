import unittest2

import ../protobuf_serialization

type
  Float2Object {.protobuf2.} = object
    a {.fieldNumber: 1.}: PBOption[1'f64]

  Float3Object {.protobuf3.} = object
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
