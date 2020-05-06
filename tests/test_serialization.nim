import
  unittest,
  ../protobuf_serialization

type
  MyEnum = enum
    ME1, ME2, ME3

  Test1 = object
    a: uint
    b: string
    c: char

  #[Test3 = object
    g {.sfixed.}: int
    h {.sint.}: int
    i: Test1
    j: string
    k: bool
    l: MyInt

  MyInt = distinct int

proc to*[MyInt](bytes: seq[byte]): MyInt =
  var
    shiftAmount: int = 0
    value: int
  for b in bytes:
    value += int(b) shl shiftAmount
    shiftAmount += 8
  result = MyInt(value)

proc toBytes*(value: MyInt): seq[byte] =
  var value = value.int

  while value > 0:
    result.add byte(value and 0b1111_1111)
    value = value shr 8

proc `==`(a, b: MyInt): bool {.borrow.}]#

suite "Test Varint Encoding":
  test "Can encode/decode enum field":
    var proto = newProtoBuffer()

    proto.encodeField(ME3)
    proto.encodeField(ME2)

    var output = proto.output
    assert output == @[8.byte, 4, 16, 2]

    let decodedME3 = readValue(output, MyEnum)
    assert decodedME3 == ME3

    let decodedME2 = readValue(output, MyEnum)
    assert decodedME2 == ME2

  test "Can encode/decode negative number field":
    var proto = newProtoBuffer()
    let num = -153452

    proto.encodeField(num)

    var output = proto.output
    assert output == @[8.byte, 215, 221, 18]

    let decoded = readValue(output, int)
    assert decoded == num

  #[test "Can encode/decode distinct number field":
    var proto = newProtoBuffer()
    let num = 114151.MyInt

    proto.encodeField(num)

    var output = proto.output
    assert output == @[10.byte, 3, 231, 189, 1]

    let decoded = readValue(output, MyInt)
    assert decoded.int == num.int]#

  test "Can encode/decode float32 number field":
    var proto = newProtoBuffer()
    let num = float32(1234.164423)

    proto.encodeField(num)

    var output = proto.output
    assert output == @[13.byte, 67, 69, 154, 68]

    let decoded = readValue(output, float32)
    assert decoded == num

  test "Can encode/decode float64 number field":
    var proto = newProtoBuffer()
    let num = 12343121537452.1644232341'f64

    proto.encodeField(num)

    var output = proto.output
    assert output == @[9.byte, 84, 88, 211, 191, 182, 115, 166, 66]

    let decoded = readValue(output, float64)
    assert decoded == num

  test "Can encode/decode bool field":
    var proto = newProtoBuffer()
    let boolean = true

    proto.encodeField(boolean)

    var output = proto.output
    assert output == @[8.byte, 1]

    let decoded = readValue(output, bool)
    assert decoded == boolean

  test "Can encode/decode char field":
    var proto = newProtoBuffer()
    let charVal = 'G'

    proto.encodeField(charVal)

    var output = proto.output
    assert output == @[8.byte, ord(charVal).byte]

    let decoded = readValue(output, char)
    assert decoded == charVal

  test "Can encode/decode unsigned number field":
    var proto = newProtoBuffer()
    let num = 123151.uint

    proto.encodeField(num)

    var output = proto.output
    assert output == @[8.byte, 143, 194, 7]

    let decoded = readValue(output, uint)
    assert decoded == num

  #[test "Can encode/decode string field":
    var proto = newProtoBuffer()
    let str = "hey this is a string"

    proto.encodeField(str)

    var output = proto.output
    assert output == @[10.byte, 20, 104, 101, 121, 32, 116, 104, 105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103]

    let decoded = readValue(output, string)
    assert decoded == str

  test "Can encode/decode char seq field":
    var proto = newProtoBuffer()
    let charSeq = cast[seq[char]]("hey this is a string")

    proto.encodeField(charSeq)

    var output = proto.output
    assert output == @[10.byte, 20, 104, 101, 121, 32, 116, 104, 105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103]

    let decoded = readValue(output, seq[char])
    assert decoded == charSeq

  test "Can encode/decode uint8 seq field":
    var proto = newProtoBuffer()
    let uint8Seq = cast[seq[uint8]]("hey this is a string")

    proto.encodeField(uint8Seq)

    var output = proto.output
    assert output == @[10.byte, 20, 104, 101, 121, 32, 116, 104, 105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103]

    let decoded = readValue(output, seq[uint8])
    assert decoded == uint8Seq]

  test "Can encode/decode object field":
    var proto = newProtoBuffer()

    let obj = Test3(g: 300, h: 200, i: Test1(a: 100, b: "this is a test", c: 'H'), j: "testing", k: true, l: 124521.MyInt)

    proto.encodeField(obj)

    var output = proto.output
    let decoded = readValue(output, Test3)
    assert decoded == obj

  test "Can encode/decode object":
    var proto = newProtoBuffer()

    let obj = Test3(g: 300, h: 200, i: Test1(a: 100, b: "this is a test", c: 'H'), j: "testing", k: true, l: 124521.MyInt)

    proto.encode(obj)
    var output = proto.output
    let decoded = output.readValue(Test3)
    assert decoded == obj

  test "Can encode/decode out of order object":
    var proto = newProtoBuffer()

    let obj = Test3(g: 400, h: 100, i: Test1(a: 100, b: "this is a test", c: 'H'), j: "testing", k: true, l: 14514.MyInt)
    proto.encodeField(6, 14514.MyInt)
    proto.encodeField(2, 100)
    proto.encodeField(4, "testing")
    proto.encodeField(1, 400)
    proto.encodeField(3, Test1(a: 100, b: "this is a test", c: 'H'))
    proto.encodeField(5, true)

    var output = proto.output
    let decoded = output.readValue(Test3)

    assert decoded == obj

  test "Empty object field does not get encoded":
    var proto = newProtoBuffer()

    let obj = Test1()
    proto.encodeField(1, obj)

    var output = proto.output
    assert output.len == 0

    let decoded = output.readValue(Test1)
    assert decoded == obj

  test "Empty object does not get encoded":
    var proto = newProtoBuffer()

    let obj = Test1()
    proto.encode(obj)

    var output = proto.output
    assert output.len == 0

    let decoded = output.readValue(Test1)
    assert decoded == obj]#
