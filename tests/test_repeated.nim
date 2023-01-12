import sets
import unittest2
import stew/byteutils
import ../protobuf_serialization

type
  # Keep in sync with test_repeated.proto
  Sequences {.proto3.} = object
    x {.fieldNumber: 1, sint, packed: false.}: seq[int32]
    y {.fieldNumber: 2, packed: false.}: seq[bool]
    z {.fieldNumber: 3.}: seq[string]

  Packed {.proto3.} = object
    x {.fieldNumber: 1, sint, packed: true.}: seq[int32]
    y {.fieldNumber: 2, packed: true.}: seq[bool]
    z {.fieldNumber: 3, fixed, packed: true.}: seq[int32]
    a {.fieldNumber: 4, packed: true.}: seq[float32]

suite "Test repeated fields":
  test "Sequences":
    # protoc --encode=Sequences test_repeated.proto | hexdump -ve '1/1 "%.2x"'
    discard """
x: [5, -3, 300, -612]
y: [true, false, true, true, false, false, false, true, false]
z: ["zero", "one", "two"]
"""
    const
      v = Sequences(
        x: @[5'i32, -3, 300, -612],
        y: @[true, false, true, true, false, false, false, true, false],
        z: @["zero", "one", "two"]
      )
      encoded = hexToSeqByte(
        "080a080508d80408c7091001100010011001100010001000100110001a047a65726f1a036f6e651a0374776f")

    check:
      Protobuf.computeSize(v) == encoded.len
      Protobuf.encode(v) == encoded
      Protobuf.decode(encoded, typeof(v)) == v

  test "Packed sequences":
    # protoc --encode=Packed test_repeated.proto | hexdump -ve '1/1 "%.2x"'
    discard """
x: [5, -3, 300, -612]
y: [true, false, true, true, false, false, false, true, false]
z: [5, -3, 300, -612]
a: [5, -3, 300, -612]
  """
    const
      v = Packed(
        x: @[5'i32, -3, 300, -612],
        y: @[true, false, true, true, false, false, false, true, false],
        z: @[5'i32, -3, 300, -612],
        a: @[5'f32, -3, 300, -612],
      )
      encoded = hexToSeqByte(
        "0a060a05d804c70912090100010100000001001a1005000000fdffffff2c0100009cfdffff22100000a040000040c000009643000019c4")

    check:
      Protobuf.computeSize(v) == encoded.len
      Protobuf.encode(v) == encoded
      Protobuf.decode(encoded, typeof(v)) == v
