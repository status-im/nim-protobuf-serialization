import options
import unittest

import ../protobuf_serialization
from ../protobuf_serialization/internal import VarIntWrapped, FixedWrapped, unwrap, flatType, flatMap

from test_objects import DistinctInt, toProtobuf, fromProtobuf, `==`

type
  Basic = object
    x {.sint.}: int32

  Wrapped = object
    y {.sint.}: Option[int32]

  Nested = ref object
    #child: Option[Nested]
    z: Option[Wrapped]

proc `==`*(lhs: Nested, rhs: Nested): bool =
  lhs.z == rhs.z

template testNone[T](ty: typedesc[T]) =
  let output = writeValue(none(ty))
  check output.len == 0
  check output.readValue(Option[T]).isNone()

template testSome[T](value: T) =
    let output = writeValue(some(value))
    check output == writeValue(flatMap(value))
    when flatType(T) is (VarIntWrapped or FixedWrapped):
      check output.readValue(Option[T]).get().unwrap() == some(value).get().unwrap()
    else:
      check output.readValue(Option[T]) == some(value)

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

    #The following test isn't possible.
    #y won't be encoded because it's none.
    #Since it's not encoded, nothing in the object will be.
    #This means the object itself won't be.
    #var noneWrapped = Wrapped(y: none(int32))
    #testSome(noneWrapped)

    var someWrapped = Wrapped(y: some(5'i32))
    testSome(someWrapped)

  test "Option ref":
    testNone(Nested)

    testSome(Nested(
      #child: none(Nested),
      z: some(Wrapped(y: some(5'i32)))
    ))

    testSome(Nested(
      #child: some(Nested(
        #child: none(Nested),
      #  z: some(Wrapped(y: some(5'i32)))
      #)),
      z: some(Wrapped(y: some(5'i32)))
    ))

    testSome(Nested(
      #child: some(Nested(
      #  z: some(Wrapped(y: some(5'i32)))
      #)),
      z: some(Wrapped(y: some(5'i32)))
    ))

  test "Option distinct type":
    testNone(DistinctInt)
    testSome(DistinctInt(5))

  #This was banned at one point in this library's lifetime.
  #It should work now.
  test "Option Option":
    testNone(string)
    testSome(some("abc"))
