import unittest

import ../protobuf_serialization
from ../protobuf_serialization/internal import unwrap

proc writeRead(x: SomeNumber) =
  check cast[uint64](Protobuf.decode(Protobuf.encode(Fixed(x)), type(Fixed(x)))) == cast[uint64](x)

suite "Test Fixed Encoding/Decoding":
  test "Can encode/decode int":
    writeRead(2'i32)
    writeRead(3'i64)
    writeRead(-4'i32)
    writeRead(-5'i64)

  test "Can encode/decode uint":
    writeRead(6'u32)
    writeRead(7'u64)

  test "Can encode/decode float":
    writeRead(8.90123'f32)
    writeRead(4.56789'f64)
    writeRead(-0.1234'f32)
    writeRead(-5.6789'f64)
