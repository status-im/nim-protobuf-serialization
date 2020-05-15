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
    i: DistinctInt

  Nested* = ref object
    child*: Nested
    data*: string

  Circular = ref object
    child: Circular

#Instead of relying on writeValue, you could instead write your own implementations.
#Any byte sequence returned by this will be passed directly to the matching fromProtobuf.
#This means doing this this way requires knowing what wire type to prepend.
#That said, as this is for distinct objects, that shouldn't be too problematic.
proc toProtobuf*(x: DistinctInt): seq[byte] =
  result = writeValue(SInt(x.int32))
  if result.len == 0:
    return
  result = result[1 ..< result.len]

proc fromProtobuf*(bytes: seq[byte], value: var DistinctInt) =
  if bytes.len == 0:
    return
  value = DistinctInt((@[wireType(SInt(int32))] & bytes).readValue(SInt(int32)))

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
  #The following two tests don't actually test objects. They test user-defined types.
  #One should be automatically resolved. One can't be resolved.
  test "Can encode/decode enums":
    template enumTest(value: TestEnum, integer: int): untyped =
      let output = writeValue(SInt(value))
      if integer == 0:
        check output.len == 0
      else:
        check output == @[byte(8), byte(integer)]
      check TestEnum(readValue(output, SInt(TestEnum))) == value

    enumTest(NegTwo, 3)
    enumTest(NegOne, 1)
    enumTest(Zero, 0)
    enumTest(One, 2)
    enumTest(Two, 4)

  test "Can encode/decode distinct types":
    var x: DistinctInt = 5.DistinctInt
    check writeValue(x).readValue(DistinctInt) == x

  test "Can encode/decode a basic object":
    let obj = Basic(a: 100, b: "Test string.", c: 'C')
    check writeValue(obj).readValue(Basic) == obj

  test "Can encode/decode a wrapper object":
    let obj = Wrapped(
      d: 300,
      e: 200,
      f: Basic(a: 100, b: "Test string.", c: 'C'),
      g: "Other test string.",
      h: true,
      i: 124521.DistinctInt
    )
    check writeValue(obj).readValue(Wrapped) == obj

  test "Can encode/decode partial object":
    let
      obj = Wrapped(
        d: 300,
        e: 200,
        f: Basic(a: 100, b: "Test string.", c: 'C'),
        g: "Other test string.",
        h: true,
        i: 124521.DistinctInt
      )
      writer = newProtobufWriter()

    writer.writeField(obj, "d")
    writer.writeField(obj, "f")
    writer.writeField(obj, "g")
    writer.writeField(obj, "i")

    let result = writer.buffer().readValue(Wrapped)
    check result.d == obj.d
    check result.f == obj.f
    check result.g == obj.g
    check result.i == obj.i
    check result.e == 0
    check result.h == false

  test "Can encode/decode out of order object":
    let
      obj = Wrapped(
        d: 300,
        e: 200,
        f: Basic(a: 100, b: "Test string.", c: 'C'),
        g: "Other test string.",
        h: true,
        i: 124521.DistinctInt
      )
      writer = newProtobufWriter()

    writer.writeField(obj, "f")
    writer.writeField(obj, "i")
    writer.writeField(obj, "d")
    writer.writeField(obj, "e")
    writer.writeField(obj, "h")
    writer.writeField(obj, "g")

    check writer.buffer().readValue(Wrapped) == obj

  test "Doesn't write too-big nested objects":
    expect ProtobufWriteError:
      discard writeValue(Nested(
        child: Nested(
          data: cast[string](newSeq[char](150))
        ),
        data: cast[string](newSeq[char](150))
      ))

  test "Doesn't write circular objects":
    let root = Circular()
    root.child = root
    expect ProtobufWriteError:
      discard writeValue(root)

  test "Doesn't fully recurse over nested objects which are too-big":
    #Created in a non-recursive format to not trigger the call depth.
    #We do use the Circular type yet we do NOT set the child back to self.
    var
      root = Circular()
      last = root
    #2000 is the call depth limit.
    #The extra 5 ensures we go over.
    for _ in 0 ..< 2005:
      last.child = Circular()
      last = last.child
    #This should raise without crashing.
    expect ProtobufWriteError:
      discard writeValue(root)

  test "Can read nested objects":
    var obj: Nested = Nested(
      child: Nested(
        data: "Child data."
      ),
      data: "Parent data."
    )
    check writeValue(obj).readValue(Nested) == obj

  test "Doesn't allow remaining data in the buffer":
    expect ProtobufDataRemainingError:
      discard (SInt(5).writeValue() & @[byte(1)]).readValue(SInt(int32))

  test "Doesn't allow unknown fields":
    expect ProtobufMessageError:
      discard (writeValue(Basic(a: 100, b: "Test string.", c: 'C')) & @[byte(4 shl 3)]).readValue(Basic)

  test "Doesn't allow duplicate fields":
    let
      obj = Basic(a: 100, b: "Test string.", c: 'C')
      writer = newProtobufWriter()

    writer.writeField(obj, "b")
    writer.writeField(obj, "b")

    expect ProtobufMessageError:
      discard writer.buffer().readValue(Wrapped)
