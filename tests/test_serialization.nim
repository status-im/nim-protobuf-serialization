import unittest

import protobuf_serialization

type
  MyEnum = enum
    ME1, ME2, ME3
type
  Test1 = object
    a: uint
    b: string

  Test3 = object
    g {.sfixed32.}: int
    h: int
    i: Test1
    j: string

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

  test "Can encode/decode object field":
    var proto = newProtoBuffer()

    let obj = Test3(g: 300, h: 200, i: Test1(a: 100, b: "this is a test"), j: "testing")

    proto.encodeField(obj)
    var offset, bytesProcessed: int

    var output = proto.output
    let decoded = decodeField(output, Test3, offset, bytesProcessed)
    assert decoded.value == obj
    assert decoded.index == 1

  test "Can encode/decode object":
    var proto = newProtoBuffer()

    let obj = Test3(g: 300, h: 200, i: Test1(a: 100, b: "this is a test"), j: "testing")

    proto.encode(obj)
    var output = proto.output
    let decoded = output.decode(Test3)
    assert decoded == obj