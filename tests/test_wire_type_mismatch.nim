import unittest2
import stew/byteutils
import ../protobuf_serialization

type
  Bytes {.proto3.} = object
    x {.fieldNumber: 1.}: seq[byte]

  Varint {.proto3.} = object
    x {.fieldNumber: 1, pint.}: int64

  Fixed32Obj {.proto3.} = object
    x {.fieldNumber: 1, fixed.}: int32

  Fixed64Obj {.proto3.} = object
    x {.fieldNumber: 1, fixed.}: int64
  
  Repeated {.proto3.} = object
    x {.fieldNumber: 1, pint.}: seq[int64]

suite "Test wire type mismatches length":
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

suite "Test wire type mismatches varint":
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

suite "Test wire type mismatches fixed32":
  test "Fixed64 instead of fixed32":
    # echo "090100000000000000" | xxd -r -p | protoc --decode=Fixed32Obj test_wire_type_mismatch.proto
    let encoded = "090100000000000000".hexToSeqByte
    check Protobuf.decode(encoded, Fixed32Obj) == Fixed32Obj()

  test "Fixed64 instead of fixed32 variant 1":
    # echo "0901000000000000000D01000000" | xxd -r -p | protoc --decode=Fixed32Obj test_wire_type_mismatch.proto
    let encoded = "0901000000000000000D01000000".hexToSeqByte
    check Protobuf.decode(encoded, Fixed32Obj) == Fixed32Obj(x: 1)

  test "Fixed64 instead of fixed32 variant 2":
    # echo "0D01000000090100000000000000" | xxd -r -p | protoc --decode=Fixed32Obj test_wire_type_mismatch.proto
    let encoded = "0D01000000090100000000000000".hexToSeqByte
    check Protobuf.decode(encoded, Fixed32Obj) == Fixed32Obj(x: 1)

  test "Varint instead of fixed32":
    # echo "0801" | xxd -r -p | protoc --decode=Fixed32Obj test_wire_type_mismatch.proto
    let encoded = "0801".hexToSeqByte
    check Protobuf.decode(encoded, Fixed32Obj) == Fixed32Obj()

  test "Varint instead of fixed32 variant 1":
    # echo "08010D01000000" | xxd -r -p | protoc --decode=Fixed32Obj test_wire_type_mismatch.proto
    let encoded = "08010D01000000".hexToSeqByte
    check Protobuf.decode(encoded, Fixed32Obj) == Fixed32Obj(x: 1)

  test "Varint instead of fixed32 variant 2":
    # echo "0D010000000801" | xxd -r -p | protoc --decode=Fixed32Obj test_wire_type_mismatch.proto
    let encoded = "0D010000000801".hexToSeqByte
    check Protobuf.decode(encoded, Fixed32Obj) == Fixed32Obj(x: 1)

  test "Length instead of fixed32":
    # echo "0a0161" | xxd -r -p | protoc --decode=Fixed32Obj test_wire_type_mismatch.proto
    let encoded = "0a0161".hexToSeqByte
    check Protobuf.decode(encoded, Fixed32Obj) == Fixed32Obj()

  test "Length instead of fixed32 variant 1":
    # echo "0a01610D01000000" | xxd -r -p | protoc --decode=Fixed32Obj test_wire_type_mismatch.proto
    let encoded = "0a01610D01000000".hexToSeqByte
    check Protobuf.decode(encoded, Fixed32Obj) == Fixed32Obj(x: 1)

  test "Length instead of fixed32 variant 2":
    # echo "0D010000000a0161" | xxd -r -p | protoc --decode=Fixed32Obj test_wire_type_mismatch.proto
    let encoded = "0D010000000a0161".hexToSeqByte
    check Protobuf.decode(encoded, Fixed32Obj) == Fixed32Obj(x: 1)

suite "Test wire type mismatches fixed64":
  test "Fixed32 instead of fixed64":
    # echo "0D01000000" | xxd -r -p | protoc --decode=Fixed64Obj test_wire_type_mismatch.proto
    # 1: 0x00000001
    let encoded = "0D01000000".hexToSeqByte
    check Protobuf.decode(encoded, Fixed64Obj) == Fixed64Obj()

  test "Fixed32 instead of fixed64 variant 1":
    # echo "0D01000000090100000000000000" | xxd -r -p | protoc --decode=Fixed64Obj test_wire_type_mismatch.proto
    # x: 1
    # 1: 0x00000001
    let encoded = "0D01000000090100000000000000".hexToSeqByte
    check Protobuf.decode(encoded, Fixed64Obj) == Fixed64Obj(x: 1)

  test "Fixed32 instead of fixed64 variant 2":
    # echo "0901000000000000000D01000000" | xxd -r -p | protoc --decode=Fixed64Obj test_wire_type_mismatch.proto
    # x: 1
    # 1: 0x00000001
    let encoded = "0901000000000000000D01000000".hexToSeqByte
    check Protobuf.decode(encoded, Fixed64Obj) == Fixed64Obj(x: 1)

  test "Varint instead of fixed64":
    # echo "0801" | xxd -r -p | protoc --decode=Fixed64Obj test_wire_type_mismatch.proto
    let encoded = "0801".hexToSeqByte
    check Protobuf.decode(encoded, Fixed64Obj) == Fixed64Obj()

  test "Varint instead of fixed64 variant 1":
    # echo "0801090100000000000000" | xxd -r -p | protoc --decode=Fixed64Obj test_wire_type_mismatch.proto
    let encoded = "0801090100000000000000".hexToSeqByte
    check Protobuf.decode(encoded, Fixed64Obj) == Fixed64Obj(x: 1)

  test "Varint instead of fixed64 variant 2":
    # echo "0901000000000000000801" | xxd -r -p | protoc --decode=Fixed64Obj test_wire_type_mismatch.proto
    let encoded = "0901000000000000000801".hexToSeqByte
    check Protobuf.decode(encoded, Fixed64Obj) == Fixed64Obj(x: 1)

  test "Length instead of fixed64":
    # echo "0a0161" | xxd -r -p | protoc --decode=Fixed64Obj test_wire_type_mismatch.proto
    let encoded = "0a0161".hexToSeqByte
    check Protobuf.decode(encoded, Fixed64Obj) == Fixed64Obj()

  test "Length instead of fixed64 variant 1":
    # echo "0a0161090100000000000000" | xxd -r -p | protoc --decode=Fixed64Obj test_wire_type_mismatch.proto
    let encoded = "0a0161090100000000000000".hexToSeqByte
    check Protobuf.decode(encoded, Fixed64Obj) == Fixed64Obj(x: 1)

  test "Length instead of fixed64 variant 2":
    # echo "0901000000000000000a0161" | xxd -r -p | protoc --decode=Fixed64Obj test_wire_type_mismatch.proto
    let encoded = "0901000000000000000a0161".hexToSeqByte
    check Protobuf.decode(encoded, Fixed64Obj) == Fixed64Obj(x: 1)

suite "Test wire type mismatches repeated varint":
  test "repeated fixed32 instead of varint":
    # echo "0D01000000" | xxd -r -p | protoc --decode=Repeated test_wire_type_mismatch.proto
    # 1: 0x00000001
    let encoded = "0D01000000".hexToSeqByte
    check Protobuf.decode(encoded, Repeated) == Repeated()

  test "repeated fixed32 instead of varint variant 1":
    # echo "08010D01000000" | xxd -r -p | protoc --decode=Repeated test_wire_type_mismatch.proto
    # x: 1
    # 1: 0x00000001
    let encoded = "08010D01000000".hexToSeqByte
    check Protobuf.decode(encoded, Repeated) == Repeated(x: @[1])

  test "repeated Length instead of varint variant 1":
    # echo "08010a0161" | xxd -r -p | protoc --decode=Repeated test_wire_type_mismatch.proto
    # x: 1
    # x: 97
    # this decodes "a" because Length-defined are packed values
    let encoded = "08010a0161".hexToSeqByte
    check Protobuf.decode(encoded, Repeated) == Repeated(x: @[1, 97])
