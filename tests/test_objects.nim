import unittest

import ../protobuf_serialization

type
  TestEnum = enum
    NegTwo = -2, NegOne, Zero, One, Two

  DistinctInt* = distinct int32

  Basic = object
    a {.puint.}: uint64
    b: string
    c {.puint.}: char

  Wrapped = object
    d {.sint.}: int32
    e {.sint.}: int64
    f: Basic
    g: string
    h: bool

  Nested* = ref object
    child*: Nested
    data*: string

  Circular = ref object
    child: Circular

  Pointered = object
    x {.sint.}: ptr int32

type DistinctTypeSerialized = SInt(int32)
DistinctInt.borrowSerialization(DistinctTypeSerialized)
proc `==`*(lhs: DistinctInt, rhs: DistinctInt): bool {.borrow.}

proc `==`*(lhs: Nested, rhs: Nested): bool =
  var
    lastLeft = lhs
    lastRight = rhs
  while not lastLeft.isNil:
    if lastRight.isNil:
      return false
    if lastLeft.data != lastRight.data:
      return false
    lastLeft = lastLeft.child
    lastRight = lastRight.child
  if not lastRight.isNil:
    return false
  result = true

suite "Test Object Encoding/Decoding":
  #The following three tests don't actually test formal objects.
  #They test user-defined types. This is just the best place for these tests.
  template enumTest(value: TestEnum, integer: int): untyped =
    let output = Protobuf.encode(SInt(value))
    if integer == 0:
      check output.len == 0
    else:
      check output == @[byte(8), byte(integer)]
    check TestEnum(Protobuf.decode(output, type(SInt(TestEnum)))) == value

  enumTest(NegTwo, 3)
  enumTest(NegOne, 1)
  enumTest(Zero, 0)
  enumTest(One, 2)
  enumTest(Two, 4)

  test "Can encode/decode distinct types":
    let x: DistinctInt = 5.DistinctInt
    check Protobuf.decode(Protobuf.encode(x), type(DistinctInt)) == x

  test "Can encode/decode tuples":
    let
      unnamed: (
        SInt(int32),
        UInt(uint32),
        bool,
        string,
        bool
      ) = (SInt(5'i32), UInt(3'u32), true, "abc", false)
      unnamedRead = Protobuf.decode(Protobuf.encode(unnamed), type(unnamed))

      named: tuple[
        a: SInt(int32),
        b: UInt(uint32),
        c: bool,
        d: string,
        e: bool
      ] = (
        a: SInt(6'i32),
        b: UInt(4'u32),
        c: false,
        d: "def",
        e: true
      )
      namedRead = Protobuf.decode(Protobuf.encode(named), type(named))

    check int32(unnamedRead[0]) == int32(unnamed[0])
    check uint32(unnamedRead[1]) == uint32(unnamed[1])
    check unnamedRead[2] == unnamed[2]
    check unnamedRead[3] == unnamed[3]
    check unnamedRead[4] == unnamed[4]

    check int32(namedRead.a) == int32(named.a)
    check uint32(namedRead.b) == uint32(named.b)
    check namedRead.c == named.c
    check namedRead.d == named.d
    check namedRead.e == named.e

    let obj = Basic(a: 100, b: "Test string.", c: 'C')
    check Protobuf.decode(Protobuf.encode(obj), type(Basic)) == obj

  test "Can encode/decode a wrapper object":
    let obj = Wrapped(
      d: 300,
      e: 200,
      f: Basic(a: 100, b: "Test string.", c: 'C'),
      g: "Other test string.",
      h: true
    )
    check Protobuf.decode(Protobuf.encode(obj), type(Wrapped)) == obj

  test "Can encode/decode partial object":
    let
      obj = Wrapped(
        d: 300,
        e: 200,
        f: Basic(a: 100, b: "Test string.", c: 'C'),
        g: "Other test string.",
        h: true
      )
      writer = ProtobufWriter.init(memoryOutput())

    writer.writeField(1, SInt(obj.d))
    writer.writeField(3, obj.f)
    writer.writeField(4, obj.g)

    let result = Protobuf.decode(writer.finish(), type(Wrapped))
    check result.d == obj.d
    check result.f == obj.f
    check result.g == obj.g
    check result.e == 0
    check result.h == false

  test "Can encode/decode out of order object":
    let
      obj = Wrapped(
        d: 300,
        e: 200,
        f: Basic(a: 100, b: "Test string.", c: 'C'),
        g: "Other test string.",
        h: true
      )
      writer = ProtobufWriter.init(memoryOutput())

    writer.writeField(3, obj.f)
    writer.writeField(1, SInt(obj.d))
    writer.writeField(2, SInt(obj.e))
    writer.writeField(5, obj.h)
    writer.writeField(4, obj.g)

    check Protobuf.decode(writer.finish(), type(Wrapped)) == obj

  test "Can read nested objects":
    let obj: Nested = Nested(
      child: Nested(
        data: "Child data."
      ),
      data: "Parent data."
    )
    check Protobuf.decode(Protobuf.encode(obj), type(Nested)) == obj

  test "Can read pointered objects":
    var ptrd = Pointered()
    ptrd.x = cast[ptr int32](alloc0(sizeof(int32)))
    ptrd.x[] = 5
    check Protobuf.decode(Protobuf.encode(ptrd), Pointered).x[] == ptrd.x[]

    var ptrPtrd = addr ptrd
    ptrPtrd.x = cast[ptr int32](alloc0(sizeof(int32)))
    ptrPtrd.x[] = 8
    check Protobuf.decode(Protobuf.encode(ptrPtrd), ptr Pointered).x[] == ptrPtrd.x[]

  test "Doesn't allow remaining data in the buffer":
    expect ProtobufReadError:
      discard Protobuf.decode(Protobuf.encode(SInt(5)) & @[byte(1)], type(SInt(int32)))
    expect ProtobufReadError:
      discard Protobuf.decode(Protobuf.encode(Basic(a: 100, b: "Test string.", c: 'C')) & @[byte(1)], type(Basic))

  test "Doesn't allow unknown fields":
    expect ProtobufMessageError:
      discard Protobuf.decode((Protobuf.encode(Basic(a: 100, b: "Test string.", c: 'C')) & @[byte(4 shl 3)]), type(Basic))

  test "Doesn't allow duplicate fields":
    let
      obj = Basic(a: 100, b: "Test string.", c: 'C')
      writer = ProtobufWriter.init(memoryOutput())

    writer.writeField(2, obj.b)
    writer.writeField(2, obj.b)

    expect ProtobufMessageError:
      discard Protobuf.decode(writer.finish(), type(Wrapped))
