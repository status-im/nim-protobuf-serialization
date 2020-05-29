import unittest

import ../protobuf_serialization

from test_objects import DistinctInt, `==`
type DistinctTypeSerialized = SInt(int32)
DistinctInt.borrowSerialization(DistinctTypeSerialized)

type
  X = object
  Y = object
    a {.pint, fieldNumber: 1.}: int32
  Z = object
    b {.dontSerialize.}: string

  DOY = object
    a {.pint, dontOmit, fieldNumber: 1.}: int32

proc writeEmpty[T](value: T) =
  check Protobuf.encode(value).len == 0

suite "Test Encoding of Empty Objects/Values":
  test "Empty boolean":
    writeEmpty(false)

  test "Empty signed VarInt":
    writeEmpty(PInt(0'i32))
    writeEmpty(PInt(0'i64))

  test "Empty unsigned VarInt":
    writeEmpty(PInt(0'u32))
    writeEmpty(PInt(0'u64))

  test "Empty zigzagged VarInt":
    writeEmpty(SInt(0'i32))
    writeEmpty(SInt(0'i64))

  test "Empty Fixed64":
    writeEmpty(Fixed(0'i64))
    writeEmpty(Fixed(0'u64))
    writeEmpty(Float64(0'f64))

  test "Empty length-delimited":
    writeEmpty("")

  test "Empty object":
    writeEmpty(X())
    writeEmpty(Y())
    writeEmpty(Z(b: "abc"))

    check Protobuf.encode(DOY()).len == 2

  test "Empty distinct type":
    writeEmpty(DistinctInt(0))

  test "Empty Fixed32":
    writeEmpty(Fixed(0'i32))
    writeEmpty(Fixed(0'u32))
    writeEmpty(Float32(0'f32))
