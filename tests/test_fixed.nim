import unittest

import ../protobuf_serialization
from ../protobuf_serialization/internal import unwrap

proc writeRead(x: auto) =
  when sizeof(x) == 4:
    check cast[uint32](Protobuf.decode(Protobuf.encode(x), type(x))) == cast[uint32](x)
  else:
    check cast[uint64](Protobuf.decode(Protobuf.encode(x), type(x))) == cast[uint64](x)

type
  Float2Object {.protobuf2.} = object
    a {.pfloat64, fieldNumber: 1.}: PBOption[1'f64]

  Float3Object {.protobuf3.} = object
    a {.pfloat32, fieldNumber: 1.}: Option[1'f32]

suite "Test Fixed Encoding/Decoding":
  test "Can encode/decode int":
    writeRead(Fixed(2'i32))
    writeRead(Fixed(3'i64))
    writeRead(Fixed(-4'i32))
    writeRead(Fixed(-5'i64))

  test "Can encode/decode uint":
    writeRead(Fixed(6'u32))
    writeRead(Fixed(7'u64))

  test "Can encode/decode float":
    writeRead(Float32(8.90123'f32))
    writeRead(Float64(4.56789'f64))
    writeRead(Float32(-0.1234'f32))
    writeRead(Float64(-5.6789'f64))

  test "Can encode/decode floats wrapped in an object":
    check:
      Protobuf.decode(
        Protobuf.encode(Float2Object(a: pbSome(PBOption[1'f64], 2.39'f64))),
        Float2Object
      ).a.get() == 2.39'f64

      Protobuf.decode(
        Protobuf.encode(Float3Object(a: some(5.64'f32))),
        Float3Object
      ).a.get() == 5.64'f32
