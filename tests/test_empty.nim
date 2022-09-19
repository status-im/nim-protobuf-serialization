import unittest

import ../protobuf_serialization

type
  X {.protobuf3.} = object
  Y {.protobuf3.} = object
    a {.pint, fieldNumber: 1.}: int32
  Z {.protobuf3.} = object
    b {.fieldNumber: 1.}: string

proc writeEmpty[T](value: T) =
  check Protobuf.encode(value).len == 0

suite "Test Encoding of Empty Objects/Values":
  test "Empty object":
    writeEmpty(X())
    writeEmpty(Y())
    writeEmpty(Z())
