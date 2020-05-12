import unittest

import ../protobuf_serialization

type
  MyEnum = enum
    ME1, ME2, ME3

  Test1 = object
    a {.puint.}: uint64
    b: string
    c {.puint.}: char

  Test3 = object
    g {.sint.}: int32
    h {.sint.}: int64
    i: Test1
    j: string
    k {.puint.}: bool
    l: MyInt

  MyInt = distinct int

proc `==`*(lhs: MyInt, rhs: MyInt): bool {.borrow.}

proc fromProtobuf*[T: MyInt](bytes: seq[byte]): T =
  var
    shiftAmount: int = 0
    value: int
  for b in bytes:
    value += int(b) shl shiftAmount
    shiftAmount += 8
  result = MyInt(value)

proc toProtobuf*(value: MyInt): seq[byte] =
  var value = value.int
  while value > 0:
    result.add byte(value and 0b1111_1111)
    value = value shr 8

suite "Test Varint Encoding":
  test "Can encode/decode enum field":
    var output = writeValue(SInt(ME3))
    check output == @[8.byte, 4]

    let decodedME3 = readValue(output, SInt(MyEnum)).MyEnum
    check decodedME3 == ME3

    output = writeValue(SInt(ME2))
    check output == @[8.byte, 2]

    let decodedME2 = readValue(output, SInt(MyEnum)).MyEnum
    check decodedME2 == ME2

  test "Can encode/decode negative number field":
    let num = -153452

    var output = writeValue(SInt(num))
    check output == @[8.byte, 215, 221, 18]

    let decoded = readValue(output, SInt(int)).int
    check decoded == num

  test "Can encode/decode distinct number field":
    let num = 114151.MyInt
    check(num.int == num.toProtobuf().fromProtobuf[:MyInt]().int)

    var output = writeValue(num)
    check output == @[10.byte, 3, 231, 189, 1]

    let decoded = readValue(output, MyInt)
    check decoded.int == num.int

  test "Can encode/decode float32 number field":
    let num = float32(1234.164423)

    var output = writeValue(num)
    check output == @[13.byte, 67, 69, 154, 68]

    let decoded = readValue(output, float32)
    check decoded == num

  test "Can encode/decode float64 number field":
    let num = 12343121537452.1644232341'f64

    var output = writeValue(num)
    check output == @[9.byte, 84, 88, 211, 191, 182, 115, 166, 66]

    let decoded = readValue(output, float64)
    check decoded == num

  test "Can encode/decode bool field":
    let boolean = true

    var output = writeValue(UInt(boolean))
    check output == @[8.byte, 1]

    let decoded = bool(readValue(output, UInt(bool)))
    check decoded == boolean

  test "Can encode/decode char field":
    let charVal = 'G'

    var output = writeValue(UInt(charVal))
    check output == @[8.byte, ord(charVal).byte]

    let decoded = readValue(output, UInt(char)).char
    check decoded == charVal

  test "Can encode/decode unsigned number field":
    let num = 123151.uint

    var output = writeValue(UInt(num))
    check output == @[8.byte, 143, 194, 7]

    let decoded = readValue(output, UInt(uint)).uint
    check decoded == num

  test "Can encode/decode string field":
    let str = "hey this is a string"

    var output = writeValue(str)
    check output == @[10.byte, 20, 104, 101, 121, 32, 116, 104, 105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103]

    let decoded = readValue(output, string)
    check decoded == str

  test "Can encode/decode char seq field":
    let charSeq = cast[seq[char]]("hey this is a string")

    var output = writeValue(charSeq)
    check output == @[10.byte, 20, 104, 101, 121, 32, 116, 104, 105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103]

    let decoded = readValue(output, seq[char])
    check decoded == charSeq

  test "Can encode/decode uint8 seq field":
    let uint8Seq = cast[seq[uint8]]("hey this is a string")

    var output = writeValue(uint8Seq)
    check output == @[10.byte, 20, 104, 101, 121, 32, 116, 104, 105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103]

    let decoded = readValue(output, seq[uint8])
    check decoded == uint8Seq

  test "Can encode/decode object":

    let obj = Test3(g: 300, h: 200, i: Test1(a: 100, b: "this is a test", c: 'H'), j: "testing", k: true, l: 124521.MyInt)

    var output = writeValue(obj)
    let decoded = output.readValue(Test3)
    check decoded == obj

  test "Can encode/decode out of order object":
    let obj = Test3(g: 400, h: 100, i: Test1(a: 100, b: "this is a test", c: 'H'), j: "testing", k: true, l: 14514.MyInt)

    var writer = newProtobufWriter()
    writer.writeField(obj, "l")
    writer.writeField(obj, "h")
    writer.writeField(obj, "j")
    writer.writeField(obj, "g")
    writer.writeField(obj, "i")
    writer.writeField(obj, "k")

    var output = writer.buffer()
    let decoded = output.readValue(Test3)

    check decoded == obj

  test "Empty object field does not get encoded":
    let obj = Test1()

    var output = writeValue(obj)
    check output.len == 0

    let decoded = output.readValue(Test1)
    check decoded == obj

  test "Empty object does not get encoded":
    let obj = Test1()

    var output = writeValue(obj)
    check output.len == 0

    let decoded = output.readValue(Test1)
    check decoded == obj
