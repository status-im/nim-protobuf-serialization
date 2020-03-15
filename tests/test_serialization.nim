import unittest

import protobuf_serialization

type
  MyEnum = enum
    ME1, ME2, ME3

suite "Test Varint Encoding":
  test "Can encode enum":
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

  test "Can encode negative number":
    let proto = newProtoBuffer()
    let num = -153452
    proto.encode(num)
    var output = proto.output
    assert output == @[8.byte, 215, 221, 18]

    let decoded = decode(output, int)
    assert decoded.value == num
    assert decoded.fieldNum == 1

  test "Can encode unsigned number":
    let proto = newProtoBuffer()
    let num = 123151.uint
    proto.encode(num)
    var output = proto.output
    assert output == @[8.byte, 143, 194, 7]

    let decoded = decode(output, uint)
    echo decoded.value
    assert decoded.value == num
    assert decoded.fieldNum == 1