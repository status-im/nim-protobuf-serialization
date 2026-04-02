import unittest2
import stew/byteutils

import ./utils, ../protobuf_serialization

type
  StringObj {.proto3.} = object
    x {.fieldNumber: 1.}: string

  BytesObj {.proto3.} = object
    x {.fieldNumber: 1.}: seq[byte]

  PInt32Obj {.proto3.} = object
    x {.fieldNumber: 1, pint.}: int32

  PUInt32Obj {.proto3.} = object
    x {.fieldNumber: 1, pint.}: uint32

  PInt64Obj {.proto3.} = object
    x {.fieldNumber: 1, pint.}: int64

  PUInt64Obj {.proto3.} = object
    x {.fieldNumber: 1, pint.}: uint64

  SInt32Obj {.proto3.} = object
    x {.fieldNumber: 1, sint.}: int32

  SInt64Obj {.proto3.} = object
    x {.fieldNumber: 1, sint.}: int64

  FixedInt32Obj {.proto3.} = object
    x {.fieldNumber: 1, fixed.}: int32

  FixedInt64Obj {.proto3.} = object
    x {.fieldNumber: 1, fixed.}: int64

  FixedUInt32Obj {.proto3.} = object
    x {.fieldNumber: 1, fixed.}: uint32

  FixedUInt64Obj {.proto3.} = object
    x {.fieldNumber: 1, fixed.}: uint64

  Float32Obj {.proto3.} = object
    x {.fieldNumber: 1.}: float32

  Float64Obj {.proto3.} = object
    x {.fieldNumber: 1.}: float64

suite "Test String Encoding/Decoding":
  test "Non-empty string values":
    # echo "0a0161" | xxd -r -p | protoc --decode=StringObj test_all_types.proto
    # echo 'x: "a"' | protoc --encode=StringObj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(StringObj(x: "a"), hexToSeqByte("0a0161"))
    roundtrip(StringObj(x: "hi"), hexToSeqByte("0a026869"))
    roundtrip(StringObj(x: "abc"), hexToSeqByte("0a03616263"))
    roundtrip(StringObj(x: "ü"), hexToSeqByte("0a02c3bc"))
    roundtrip(StringObj(x: "水"), hexToSeqByte("0a03e6b0b4"))
    roundtrip(StringObj(x: "𐅑"), hexToSeqByte("0a04f0908591"))

  test "Empty string is default":
    check Protobuf.encode(StringObj()).len == 0

suite "Test Bytes Encoding/Decoding":
  test "Non-empty byte sequences":
    # echo "0a0101" | xxd -r -p | protoc --decode=BytesObj test_all_types.proto
    # echo 'x: "\001"' | protoc --encode=BytesObj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(BytesObj(x: @[0x01'u8]), hexToSeqByte("0a0101"))
    roundtrip(BytesObj(x: @[0x01'u8, 0x02, 0x03]), hexToSeqByte("0a03010203"))
    roundtrip(BytesObj(x: @[0xFF'u8, 0x00, 0xFF]), hexToSeqByte("0a03ff00ff"))

  test "Empty bytes is default":
    check Protobuf.encode(BytesObj()).len == 0

suite "Test pint Encoding/Decoding":
  test "pint int32 single-byte varint":
    # echo "0801" | xxd -r -p | protoc --decode=PInt32Obj test_all_types.proto
    # echo 'x: 1' | protoc --encode=PInt32Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(PInt32Obj(x: 1'i32), hexToSeqByte("0801"))
    roundtrip(PInt32Obj(x: 127'i32), hexToSeqByte("087f"))

  test "pint int32 multi-byte varint":
    # echo "088001" | xxd -r -p | protoc --decode=PInt32Obj test_all_types.proto
    # echo 'x: 128' | protoc --encode=PInt32Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(PInt32Obj(x: 128'i32), hexToSeqByte("088001"))
    roundtrip(PInt32Obj(x: 300'i32), hexToSeqByte("08ac02"))
    roundtrip(PInt32Obj(x: int32.high), hexToSeqByte("08ffffffff07"))

  test "pint uint32 max value":
    # echo "08ffffffff0f" | xxd -r -p | protoc --decode=PUInt32Obj test_all_types.proto
    # echo 'x: 4294967295' | protoc --encode=PUInt32Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(PUInt32Obj(x: uint32.high), hexToSeqByte("08ffffffff0f"))

  test "pint int64 max value":
    # echo "08ffffffffffffffff7f" | xxd -r -p | protoc --decode=PInt64Obj test_all_types.proto
    # echo 'x: 9223372036854775807' | protoc --encode=PInt64Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(PInt64Obj(x: int64.high), hexToSeqByte("08ffffffffffffffff7f"))

  test "pint uint64 max value":
    # echo "08ffffffffffffffffff01" | xxd -r -p | protoc --decode=PUInt64Obj test_all_types.proto
    # echo 'x: 18446744073709551615' | protoc --encode=PUInt64Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(PUInt64Obj(x: uint64.high), hexToSeqByte("08ffffffffffffffffff01"))

suite "Test sint Encoding/Decoding":
  test "sint int32 positive values":
    # echo "0802" | xxd -r -p | protoc --decode=SInt32Obj test_all_types.proto
    # echo 'x: 1' | protoc --encode=SInt32Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(SInt32Obj(x: 1'i32), hexToSeqByte("0802"))
    roundtrip(SInt32Obj(x: 63'i32), hexToSeqByte("087e"))

  test "sint int32 negative values":
    # echo "0801" | xxd -r -p | protoc --decode=SInt32Obj test_all_types.proto
    # echo 'x: -1' | protoc --encode=SInt32Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(SInt32Obj(x: -1'i32), hexToSeqByte("0801"))
    roundtrip(SInt32Obj(x: -2'i32), hexToSeqByte("0803"))

  test "sint int32 boundary values":
    # echo "08feffffff0f" | xxd -r -p | protoc --decode=SInt32Obj test_all_types.proto
    # echo 'x: 2147483647' | protoc --encode=SInt32Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(SInt32Obj(x: int32.high), hexToSeqByte("08feffffff0f"))
    roundtrip(SInt32Obj(x: int32.low), hexToSeqByte("08ffffffff0f"))

  test "sint int64 negative values":
    # echo "0801" | xxd -r -p | protoc --decode=SInt64Obj test_all_types.proto
    # echo 'x: -1' | protoc --encode=SInt64Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(SInt64Obj(x: -1'i64), hexToSeqByte("0801"))
    roundtrip(SInt64Obj(x: int64.low), hexToSeqByte("08ffffffffffffffffff01"))

suite "Test Fixed-Width Encoding/Decoding":
  test "fixed int32 (sfixed32)":
    # echo "0d01000000" | xxd -r -p | protoc --decode=FixedInt32Obj test_all_types.proto
    # echo 'x: 1' | protoc --encode=FixedInt32Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(FixedInt32Obj(x: 1'i32), hexToSeqByte("0d01000000"))
    roundtrip(FixedInt32Obj(x: -1'i32), hexToSeqByte("0dffffffff"))
    roundtrip(FixedInt32Obj(x: int32.high), hexToSeqByte("0dffffff7f"))
    roundtrip(FixedInt32Obj(x: int32.low), hexToSeqByte("0d00000080"))

  test "fixed int64 (sfixed64)":
    # echo "090100000000000000" | xxd -r -p | protoc --decode=FixedInt64Obj test_all_types.proto
    # echo 'x: 1' | protoc --encode=FixedInt64Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(FixedInt64Obj(x: 1'i64), hexToSeqByte("090100000000000000"))
    roundtrip(FixedInt64Obj(x: -1'i64), hexToSeqByte("09ffffffffffffffff"))

  test "fixed uint32 (fixed32)":
    # echo "0d01000000" | xxd -r -p | protoc --decode=FixedUInt32Obj test_all_types.proto
    # echo 'x: 1' | protoc --encode=FixedUInt32Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(FixedUInt32Obj(x: 1'u32), hexToSeqByte("0d01000000"))
    roundtrip(FixedUInt32Obj(x: uint32.high), hexToSeqByte("0dffffffff"))

  test "fixed uint64 (fixed64)":
    # echo "090100000000000000" | xxd -r -p | protoc --decode=FixedUInt64Obj test_all_types.proto
    # echo 'x: 1' | protoc --encode=FixedUInt64Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(FixedUInt64Obj(x: 1'u64), hexToSeqByte("090100000000000000"))
    roundtrip(FixedUInt64Obj(x: uint64.high), hexToSeqByte("09ffffffffffffffff"))

suite "Test Float Encoding/Decoding":
  test "float32 values":
    # echo "0d0000803f" | xxd -r -p | protoc --decode=Float32Obj test_all_types.proto
    # echo 'x: 1' | protoc --encode=Float32Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(Float32Obj(x: 1.0'f32), hexToSeqByte("0d0000803f"))
    roundtrip(Float32Obj(x: -1.0'f32), hexToSeqByte("0d000080bf"))

  test "float64 values":
    # echo "09000000000000f03f" | xxd -r -p | protoc --decode=Float64Obj test_all_types.proto
    # echo 'x: 1' | protoc --encode=Float64Obj test_all_types.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(Float64Obj(x: 1.0'f64), hexToSeqByte("09000000000000f03f"))
    roundtrip(Float64Obj(x: -1.0'f64), hexToSeqByte("09000000000000f0bf"))
