import options
import unittest

import ../protobuf_serialization
from ../protobuf_serialization/internal import VarIntWrapped, FixedWrapped, unwrap, flatType, flatMap

from test_objects import DistinctInt, `==`

type
  Basic = object
    x {.sint.}: int32

  Wrapped = object
    y {.sint.}: Option[int32]

  Nested = ref object
    child: Option[Nested]
    z: Option[Wrapped]

proc `==`*(lhs: Nested, rhs: Nested): bool =
  lhs.z == rhs.z

template testNone[T](ty: typedesc[T]) =
  let output = Protobuf.encode(none(ty))
  check output.len == 0
  check Protobuf.decode(output, type(Option[T])).isNone()

template testSome[T](value: T) =
    let output = Protobuf.encode(some(value))
    check output == Protobuf.encode(flatMap(value))
    when flatType(T) is (VarIntWrapped or FixedWrapped):
      check Protobuf.decode(output, type(Option[T])).get().unwrap() == some(value).get().unwrap()
    else:
      check Protobuf.decode(output, type(Option[T])) == some(value)

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

    fixedTest(Fixed(5'i64))
    fixedTest(Fixed(-5'i64))
    fixedTest(Fixed(5'i32))
    fixedTest(Fixed(-5'i32))

    fixedTest(Fixed(5'u64))
    fixedTest(Fixed(5'u32))

    fixedTest(Fixed(5.5'f64))
    fixedTest(Fixed(-5.5'f64))
    fixedTest(Fixed(5.5'f32))
    fixedTest(Fixed(-5.5'f32))

  test "Option length-delimited":
    testNone(string)
    testNone(seq[byte])

    testSome("Testing string.")
    testSome(@[byte(0), 1, 2, 3, 4])

  test "Option object":
    testNone(Basic)
    testNone(Wrapped)

    testSome(Basic(x: 5'i32))
    testSome(Wrapped(y: some(5'i32)))

  test "Option ref":
    #This is in a block, manually expanded, with a pointless initial value.
    #Why?
    #https://github.com/nim-lang/Nim/issues/14387
    block one4387:
      var option = some(Nested())
      option = none(Nested)

      let output = Protobuf.encode(option)
      check output.len == 0
      check Protobuf.decode(output, type(Option[Nested])).isNone()

    testSome(Nested(
      child: some(Nested(
        child: none(Nested),
        z: none(Wrapped)
      )),
      z: none(Wrapped)
    ))

    testSome(Nested(
      child: none(Nested),
      z: some(Wrapped(y: some(5'i32)))
    ))

    testSome(Nested(
      child: some(Nested(
        child: none(Nested),
        z: some(Wrapped(y: some(5'i32)))
      )),
      z: some(Wrapped(y: some(5'i32)))
    ))

    testSome(Nested(
      child: some(Nested(
        z: some(Wrapped(y: some(5'i32)))
      )),
      z: some(Wrapped(y: some(5'i32)))
    ))

  test "Option ptr":
    testNone(ptr Basic)

    let basicInst = Basic(x: 5'i32)
    let output = Protobuf.encode(some(basicInst))
    check output == Protobuf.encode(flatMap(basicInst))
    check Protobuf.decode(output, Option[ptr Basic]).get()[] == basicInst

  #This was banned at one point in this library's lifetime.
  #It should work now.
  test "Option Option":
    testNone(string)
    testSome(some("abc"))
