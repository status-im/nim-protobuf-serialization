import unittest

import ../protobuf_serialization

type X = object
  x00: bool
  x01: bool
  x02: bool
  x03: bool
  x04: bool
  x05: bool
  x06: bool
  x07: bool
  x08: bool
  x09: bool
  x0A: bool
  x0B: bool
  x0C: bool
  x0D: bool
  x0E: bool
  x0F: bool
  x10: bool
  x11: bool
  x12: bool
  x13: bool
  x14: bool
  x15: bool
  x16: bool
  x17: bool
  x18: bool
  x19: bool
  x1A: bool
  x1B: bool
  x1C: bool
  x1D: bool
  x1E: bool
  x1F: bool
  x20: bool

suite "Thirty-three fielded object":
  test "Can encode and decode an object with 33 fields":
    let x = X(
      x00: true,
      x01: true,
      x02: true,
      x03: true,
      x04: true,
      x05: true,
      x06: true,
      x07: true,
      x08: true,
      x09: true,
      x0A: true,
      x0B: true,
      x0C: true,
      x0D: true,
      x0E: true,
      x0F: true,
      x10: true,
      x11: true,
      x12: true,
      x13: true,
      x14: true,
      x15: true,
      x16: true,
      x17: true,
      x18: true,
      x19: true,
      x1A: true,
      x1B: true,
      x1C: true,
      x1D: true,
      x1E: true,
      x1F: true,
      x20: true
    )
    check Protobuf.decode(Protobuf.encode(x), X) == x
