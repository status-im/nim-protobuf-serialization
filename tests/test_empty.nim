import unittest2

import ../protobuf_serialization

type
  X {.proto3.} = object
  Y {.proto3.} = object
    a {.pint, fieldNumber: 1.}: int32
  Z {.proto3.} = object
    b {.fieldNumber: 1.}: string

proc writeEmpty[T](value: T) =
  check Protobuf.encode(value).len == 0

suite "Test Encoding of Empty Objects/Values":
  test "Empty object":
    writeEmpty(X())
    writeEmpty(Y())
    writeEmpty(Z())
