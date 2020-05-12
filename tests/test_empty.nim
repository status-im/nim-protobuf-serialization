import unittest

import ../protobuf_serialization

type X = object
  y {.pint.}: int

suite "Test Encoding of Empty Objects/Values":
  test "Empty boolean":
    check writeValue(false).len == 0

  test "Empty signed VarInt":
    check writeValue(PInt(0'i32)).len == 0
    check writeValue(PInt(0'i64)).len == 0

  test "Empty unsigned VarInt":
    check writeValue(UInt(0'u32)).len == 0
    check writeValue(UInt(0'u64)).len == 0

  test "Empty zigzagged VarInt":
    check writeValue(SInt(0'i32)).len == 0
    check writeValue(SInt(0'i64)).len == 0

  test "Empty fixed64":
    check writeValue(SFixed(0'i64)).len == 0
    check writeValue(Fixed(0'u64)).len == 0
    check writeValue(SFixed(0'f64)).len == 0

  test "Empty length-delimited":
    check writeValue("").len == 0

  test "Empty object":
    check writeValue(X()).len == 0

  test "Empty distinct type":
    discard

  test "Empty fixed32":
    check writeValue(SFixed(0'i32)).len == 0
    check writeValue(Fixed(0'u32)).len == 0
    check writeValue(SFixed(0'f32)).len == 0
