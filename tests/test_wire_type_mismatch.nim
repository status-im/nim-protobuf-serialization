import unittest2
import stew/byteutils
import ../protobuf_serialization

type
  Bytes {.proto3.} = object
    x {.fieldNumber: 1.}: seq[byte]

  Varint {.proto3.} = object
    x {.fieldNumber: 1, pint.}: int64

suite "Test wire type mismatches":
  test "Varint instead of length":
    # echo "0801" | xxd -r -p | protoc --decode=Bytes test_wire_type_mismatch.proto
    # 1: 1
    let encoded = "0801".hexToSeqByte
    check Protobuf.decode(encoded, Bytes) == Bytes()

  test "Varint instead of length variant 1":
    # echo "08010a0161" | xxd -r -p | protoc --decode=Bytes test_wire_type_mismatch.proto
    # x: "a"
    # 1: 1
    let encoded = "08010a0161".hexToSeqByte
    check Protobuf.decode(encoded, Bytes) == Bytes(x: @['a'.byte])

  test "Varint instead of length variant 2":
    # echo "0a01610801" | xxd -r -p | protoc --decode=Bytes test_wire_type_mismatch.proto
    # x: "a"
    # 1: 1
    let encoded = "0a01610801".hexToSeqByte
    check Protobuf.decode(encoded, Bytes) == Bytes(x: @['a'.byte])

  test "Length instead of varint":
    # echo "0a0161" | xxd -r -p | protoc --decode=Varint test_wire_type_mismatch.proto
    # 1: "a"
    let encoded = "0a0161".hexToSeqByte
    check Protobuf.decode(encoded, Varint) == Varint()

  test "Length instead of varint variant 1":
    # echo "08010a0161" | xxd -r -p | protoc --decode=Varint test_wire_type_mismatch.proto
    # x: 1
    # 1: "a"
    let encoded = "08010a0161".hexToSeqByte
    check Protobuf.decode(encoded, Varint) == Varint(x: 1)

  test "Length instead of varint variant 2":
    # echo "0a01610801" | xxd -r -p | protoc --decode=Varint test_wire_type_mismatch.proto
    # x: 1
    # 1: "a"
    let encoded = "0a01610801".hexToSeqByte
    check Protobuf.decode(encoded, Varint) == Varint(x: 1)

