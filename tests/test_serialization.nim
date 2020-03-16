import unittest

import protobuf_serialization

type
  MyEnum = enum
    ME1, ME2, ME3

suite "Test Varint Encoding":
  test "Can encode/decode enum":
    let proto = newProtoBuffer()
    proto.encode(ME3)
    proto.encode(ME2)
    var output = proto.output
    assert output == @[8.byte, 4, 16, 2]

    let decodedME3 = decode(output, MyEnum)
    assert decodedME3.value == ME3
    assert decodedME3.fieldNum == 1

    let decodedME2 = decode(output, MyEnum, offset=decodedME3.bytesProcessed)
    assert decodedME2.value == ME2
    assert decodedME2.fieldNum == 2

  test "Can encode/decode negative number":
    let proto = newProtoBuffer()
    let num = -153452
    proto.encode(num)
    var output = proto.output
    assert output == @[8.byte, 215, 221, 18]

    let decoded = decode(output, int)
    assert decoded.value == num
    assert decoded.fieldNum == 1

  test "Can encode/decode unsigned number":
    let proto = newProtoBuffer()
    let num = 123151.uint
    proto.encode(num)
    var output = proto.output
    assert output == @[8.byte, 143, 194, 7]

    let decoded = decode(output, uint)
    assert decoded.value == num
    assert decoded.fieldNum == 1

  test "Can encode/decode string":
    let proto = newProtoBuffer()
    let str = "hey this is a string"
    proto.encode(str)
    var output = proto.output
    assert output == @[10.byte, 20, 104, 101, 121, 32, 116, 104, 105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103]

    let decoded = decode(output, string)
    assert decoded.value == str
    assert decoded.fieldNum == 1