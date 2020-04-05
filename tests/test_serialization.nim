import unittest
import sequtils

import protobuf_serialization

type
  MyEnum = enum
    ME1, ME2, ME3
type
  Test1 = object
    a: uint
    b: string
    c: char

  Test3 = object
    g {.sfixed32.}: int
    h: int
    i: Test1
    j: string
    k: bool

suite "Test Varint Encoding":
  test "Can encode/decode enum field":
    var proto = newProtoBuffer()
    var bytesProcessed: int

    proto.encodeField(ME3)
    proto.encodeField(ME2)

    var output = proto.output
    assert output == @[8.byte, 4, 16, 2]

    var offset = 0

    let decodedME3 = decodeField(output, MyEnum, offset, bytesProcessed)
    assert decodedME3.value == ME3
    assert decodedME3.index == 1

    let decodedME2 = decodeField(output, MyEnum, offset, bytesProcessed)
    assert decodedME2.value == ME2
    assert decodedME2.index == 2

  test "Can encode/decode negative number field":
    var proto = newProtoBuffer()
    let num = -153452
    var bytesProcessed: int

    proto.encodeField(num)

    var output = proto.output
    assert output == @[8.byte, 215, 221, 18]

    var offset = 0
    let decoded = decodeField(output, int, offset, bytesProcessed)
    assert decoded.value == num
    assert decoded.index == 1

  test "Can encode/decode float32 number field":
    var proto = newProtoBuffer()
    let num = float32(1234.164423)
    var bytesProcessed: int

    proto.encodeField(num)

    var output = proto.output
    assert output == @[13.byte, 67, 69, 154, 68]

    var offset = 0
    let decoded = decodeField(output, float32, offset, bytesProcessed)
    assert decoded.value == num
    assert decoded.index == 1

  test "Can encode/decode float64 number field":
    var proto = newProtoBuffer()
    let num = 12343121537452.1644232341'f64
    var bytesProcessed: int

    proto.encodeField(num)

    var output = proto.output
    assert output == @[9.byte, 84, 88, 211, 191, 182, 115, 166, 66]

    var offset = 0
    let decoded = decodeField(output, float64, offset, bytesProcessed)
    assert decoded.value == num
    assert decoded.index == 1

  test "Can encode/decode bool field":
    var proto = newProtoBuffer()
    let boolean = true
    var bytesProcessed: int

    proto.encodeField(boolean)

    var output = proto.output
    assert output == @[8.byte, 1]

    var offset = 0
    let decoded = decodeField(output, bool, offset, bytesProcessed)
    assert bytesProcessed == 2
    assert decoded.value == boolean
    assert decoded.index == 1

  test "Can encode/decode char field":
    var proto = newProtoBuffer()
    let charVal = 'G'
    var bytesProcessed: int

    proto.encodeField(charVal)

    var output = proto.output
    assert output == @[8.byte, ord(charVal).byte]

    var offset = 0
    let decoded = decodeField(output, char, offset, bytesProcessed)
    assert bytesProcessed == 2
    assert decoded.value == charVal
    assert decoded.index == 1

  test "Can encode/decode unsigned number field":
    var proto = newProtoBuffer()
    let num = 123151.uint
    var bytesProcessed: int

    proto.encodeField(num)

    var output = proto.output
    assert output == @[8.byte, 143, 194, 7]
    var offset = 0

    let decoded = decodeField(output, uint, offset, bytesProcessed)
    assert decoded.value == num
    assert decoded.index == 1

  test "Can encode/decode string field":
    var proto = newProtoBuffer()
    let str = "hey this is a string"
    var bytesProcessed: int

    proto.encodeField(str)

    var output = proto.output
    assert output == @[10.byte, 20, 104, 101, 121, 32, 116, 104, 105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103]

    var offset = 0
    let decoded = decodeField(output, string, offset, bytesProcessed)
    assert decoded.value == str
    assert decoded.index == 1

  test "Can encode/decode char seq field":
    var proto = newProtoBuffer()
    let charSeq = "hey this is a string".toSeq
    var bytesProcessed: int

    proto.encodeField(charSeq)

    var output = proto.output
    assert output == @[10.byte, 20, 104, 101, 121, 32, 116, 104, 105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103]

    var offset = 0
    let decoded = decodeField(output, seq[char], offset, bytesProcessed)
    assert decoded.value == charSeq
    assert decoded.index == 1

  test "Can encode/decode uint8 seq field":
    var proto = newProtoBuffer()
    let uint8Seq = cast[seq[uint8]]("hey this is a string".toSeq)
    var bytesProcessed: int

    proto.encodeField(uint8Seq)

    var output = proto.output
    assert output == @[10.byte, 20, 104, 101, 121, 32, 116, 104, 105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103]

    var offset = 0
    let decoded = decodeField(output, seq[uint8], offset, bytesProcessed)
    assert decoded.value == uint8Seq
    assert decoded.index == 1

  test "Can encode/decode object field":
    var proto = newProtoBuffer()

    let obj = Test3(g: 300, h: 200, i: Test1(a: 100, b: "this is a test", c: 'H'), j: "testing", k: true)

    proto.encodeField(obj)
    var offset, bytesProcessed: int

    var output = proto.output
    let decoded = decodeField(output, Test3, offset, bytesProcessed)
    assert decoded.value == obj
    assert decoded.index == 1

  test "Can encode/decode object":
    var proto = newProtoBuffer()

    let obj = Test3(g: 300, h: 200, i: Test1(a: 100, b: "this is a test", c: 'H'), j: "testing", k: true)

    proto.encode(obj)
    var output = proto.output
    let decoded = output.decode(Test3)
    assert decoded == obj

  test "Can encode/decode out of order object":
    var proto = newProtoBuffer()

    let obj = Test3(g: 400, h: 100, i: Test1(a: 100, b: "this is a test", c: 'H'), j: "testing", k: true)
    proto.encodeField(2, 100)
    proto.encodeField(4, "testing")
    proto.encodeField(1, 400)
    proto.encodeField(3, Test1(a: 100, b: "this is a test", c: 'H'))
    proto.encodeField(5, true)

    var output = proto.output
    let decoded = output.decode(Test3)

    assert decoded == obj

  test "Empty object field does not get encoded":
    var proto = newProtoBuffer()

    let obj = Test1()
    proto.encodeField(1, obj)

    var output = proto.output
    assert output.len == 0

    let decoded = output.decode(Test1)
    assert decoded == obj

  test "Empty object does not get encoded":
    var proto = newProtoBuffer()

    let obj = Test1()
    proto.encode(obj)

    var output = proto.output
    assert output.len == 0

    let decoded = output.decode(Test1)
    assert decoded == obj