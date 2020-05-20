import unittest

import ../protobuf_serialization

from test_objects import DistinctInt, toProtobuf, `==`

type
  X = object
  Y = object
    a {.pint.}: int32
  Z = object
    b {.dontSerialize.}: string

proc writeEmpty[T](value: T) =
  check writeValue(value).len == 0

suite "Test Encoding of Empty Objects/Values":
  test "Empty boolean":
    writeEmpty(false)

  test "Empty signed VarInt":
    writeEmpty(PInt(0'i32))
    writeEmpty(PInt(0'i64))

  test "Empty unsigned VarInt":
    writeEmpty(UInt(0'u32))
    writeEmpty(UInt(0'u64))

  test "Empty zigzagged VarInt":
    writeEmpty(SInt(0'i32))
    writeEmpty(SInt(0'i64))

  test "Empty Fixed64":
    writeEmpty(Fixed(0'i64))
    writeEmpty(Fixed(0'u64))
    writeEmpty(Fixed(0'f64))

  test "Empty length-delimited":
    writeEmpty("")

  test "Empty object":
    writeEmpty(X())
    writeEmpty(Y())
    writeEmpty(Z(b: "abc"))

  test "Empty distinct type":
    writeEmpty(DistinctInt(0))

  test "Empty Fixed32":
    writeEmpty(Fixed(0'i32))
    writeEmpty(Fixed(0'u32))
    writeEmpty(Fixed(0'f32))
