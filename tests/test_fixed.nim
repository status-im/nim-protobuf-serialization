import unittest

import ../protobuf_serialization
from ../protobuf_serialization/internal import unwrap

proc writeRead(x: auto) =
  when sizeof(x) == 4:
    check cast[uint32](Protobuf.decode(Protobuf.encode(x), type(x))) == cast[uint32](x)
  else:
    check cast[uint64](Protobuf.decode(Protobuf.encode(x), type(x))) == cast[uint64](x)

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
