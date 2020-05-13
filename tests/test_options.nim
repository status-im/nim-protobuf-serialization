import options
import unittest

import ../protobuf_serialization
from ../protobuf_serialization/internal import unwrap

template testNone[T](ty: typedesc[T]) =
  let output = writeValue(none(ty))
  check output.len == 0
  check output.readValue(Option[T]).isNone()

template testSome[T](value: T) =
    let output = writeValue(some(value))
    check output == writeValue(value)
    when T is bool:
      check output.readValue(Option[T]) == some(value)
    else:
      check output.readValue(Option[T]).get().unwrap() == some(value).get().unwrap()

suite "Test Encoding/Decoding of Options":
  test "Option boolean":
    testNone(bool)
    testSome(true)

  test "Option signed VarInt":
    testNone(PInt(int32))
    testSome(PInt(5'i32))
    testSome(PInt(-5'i32))

  test "Option unsigned VarInt":
    testNone(UInt(uint32))
    testSome(UInt(5'u32))

  test "Option zigzagged VarInt":
    testNone(SInt(int32))
    testSome(SInt(5'i32))
    testSome(SInt(-5'i32))

  test "Option Fixed":
    template fixedTest[T](value: T): untyped =
      testNone(type(T))
      testSome(value)

    fixedTest(SFixed(5'i64))
    fixedTest(SFixed(-5'i64))
    fixedTest(SFixed(5'i32))
    fixedTest(SFixed(-5'i32))

    fixedTest(Fixed(5'u64))
    fixedTest(Fixed(5'u32))

    fixedTest(SFixed(5.5'f64))
    fixedTest(SFixed(-5.5'f64))
    fixedTest(SFixed(5.5'f32))
    fixedTest(SFixed(-5.5'f32))

  #[test "Option length-delimited":
    check writeValue("").len == 5

  test "Option object":
    check writeValue(X()).len == 5

  test "Option distinct type":
    check writeValue(DistinctInt(5)).len == 5]#
