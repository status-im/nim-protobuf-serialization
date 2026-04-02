# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2
import stew/byteutils

import ./utils, ../protobuf_serialization

type
  BoolObj {.proto3.} = object
    x {.fieldNumber: 1.}: bool

  PInt32Obj {.proto3.} = object
    x {.fieldNumber: 1, pint.}: int32

  PUInt32Obj {.proto3.} = object
    x {.fieldNumber: 1, pint.}: uint32

  PInt64Obj {.proto3.} = object
    x {.fieldNumber: 1, pint.}: int64

  PUInt64Obj {.proto3.} = object
    x {.fieldNumber: 1, pint.}: uint64

  FixedInt32Obj {.proto3.} = object
    x {.fieldNumber: 1, fixed.}: int32

  FixedInt64Obj {.proto3.} = object
    x {.fieldNumber: 1, fixed.}: int64

  FixedUInt32Obj {.proto3.} = object
    x {.fieldNumber: 1, fixed.}: uint32

  FixedUInt64Obj {.proto3.} = object
    x {.fieldNumber: 1, fixed.}: uint64

  SInt32Obj {.proto3.} = object
    x {.fieldNumber: 1, sint.}: int32

  SInt64Obj {.proto3.} = object
    x {.fieldNumber: 1, sint.}: int64

suite "Test int64 to int32 truncation":
  test "Int64 is truncated to int32":
    # echo 'x: 0x7FFFFFFFFFFFFFFF' | protoc --encode=PInt64Obj test_truncation.proto | hexdump -ve '1/1 "%.2x"'
    # 08ffffffffffffffff7f
    # echo "08ffffffffffffffff7f" | xxd -r -p | protoc --decode=PInt32Obj test_truncation.proto
    # x: -1
    roundtrip(PInt64Obj(x: int64.high), PInt32Obj(x: -1'i32), hexToSeqByte("08ffffffffffffffff7f"))
    roundtrip(PInt64Obj(x: 0xFFFFFFFF0000'i64), PInt32Obj(x: 0xFFFF0000'i32), hexToSeqByte("088080fcffffff3f"))
    roundtrip(PInt64Obj(x: 0xFFFF0000FFFF'i64), PInt32Obj(x: 0xFFFF'i32), hexToSeqByte("08ffff8380f0ff3f"))

  test "Int64 is truncated to uint32":
    # echo "08ffffffffffffffff7f" | xxd -r -p | protoc --decode=PUInt32Obj test_truncation.proto
    # x: 4294967295
    roundtrip(PInt64Obj(x: int64.high), PUInt32Obj(x: uint32.high), hexToSeqByte("08ffffffffffffffff7f"))
    roundtrip(PInt64Obj(x: 0xFFFFFFFF0000'i64), PUInt32Obj(x: 0xFFFF0000'u32), hexToSeqByte("088080fcffffff3f"))
    roundtrip(PInt64Obj(x: 0xFFFF0000FFFF'i64), PUInt32Obj(x: 0xFFFF'u32), hexToSeqByte("08ffff8380f0ff3f"))

suite "Test uint64 truncation":
  test "Uint64 is truncated to int32":
    # echo 'x: 0xFFFFFFFFFFFFFFFF' | protoc --encode=PUInt64Obj test_truncation.proto | hexdump -ve '1/1 "%.2x"'
    # 08ffffffffffffffffff01
    # echo "08ffffffffffffffffff01" | xxd -r -p | protoc --decode=PInt32Obj test_truncation.proto
    # x: -1
    roundtrip(PUInt64Obj(x: uint64.high), PInt32Obj(x: -1'i32), hexToSeqByte("08ffffffffffffffffff01"))
    roundtrip(PUInt64Obj(x: 0xFFFF0000FFFF0000'u64), PInt32Obj(x: 0xFFFF0000'i32), hexToSeqByte("088080fcff8f80c0ffff01"))
    roundtrip(PUInt64Obj(x: 0xFFFF00000000FFFF'u64), PInt32Obj(x: 0xFFFF'i32), hexToSeqByte("08ffff83808080c0ffff01"))

  test "Uint64 is truncated to uint32":
    # echo "08ffffffffffffffffff01" | xxd -r -p | protoc --decode=PUInt32Obj test_truncation.proto
    # x: 4294967295
    roundtrip(PUInt64Obj(x: uint64.high), PUInt32Obj(x: uint32.high), hexToSeqByte("08ffffffffffffffffff01"))
    roundtrip(PUInt64Obj(x: 0xFFFF0000FFFF0000'u64), PUInt32Obj(x: 0xFFFF0000'u32), hexToSeqByte("088080fcff8f80c0ffff01"))
    roundtrip(PUInt64Obj(x: 0xFFFF00000000FFFF'u64), PUInt32Obj(x: 0xFFFF'u32), hexToSeqByte("08ffff83808080c0ffff01"))

  test "Uint64 is truncated to int64":
    # echo "08ffffffffffffffffff01" | xxd -r -p | protoc --decode=PInt64Obj test_truncation.proto
    # x: -1
    roundtrip(PUInt64Obj(x: uint64.high), PInt64Obj(x: -1'i64), hexToSeqByte("08ffffffffffffffffff01"))
    roundtrip(PUInt64Obj(x: uint64.high - 1), PInt64Obj(x: -2'i64), hexToSeqByte("08feffffffffffffffff01"))

suite "Test bool compatibility":
  test "Bool true decoded as int32":
    # echo "0801" | xxd -r -p | protoc --decode=PInt32Obj test_truncation.proto
    # x: 1
    roundtrip(BoolObj(x: true), PInt32Obj(x: 1'i32), hexToSeqByte("0801"))

  test "Bool true decoded as uint32":
    # echo "0801" | xxd -r -p | protoc --decode=PUInt32Obj test_truncation.proto
    # x: 1
    roundtrip(BoolObj(x: true), PUInt32Obj(x: 1'u32), hexToSeqByte("0801"))

  test "Bool true decoded as int64":
    # echo "0801" | xxd -r -p | protoc --decode=PInt64Obj test_truncation.proto
    # x: 1
    roundtrip(BoolObj(x: true), PInt64Obj(x: 1'i64), hexToSeqByte("0801"))

  test "Bool true decoded as uint64":
    # echo "0801" | xxd -r -p | protoc --decode=PUInt64Obj test_truncation.proto
    # x: 1
    roundtrip(BoolObj(x: true), PUInt64Obj(x: 1'u64), hexToSeqByte("0801"))

  test "Non-zero varint decoded as bool":
    # echo "088002" | xxd -r -p | protoc --decode=BoolObj test_truncation.proto
    # x: true
    roundtrip(PInt32Obj(x: 256'i32), BoolObj(x: true), hexToSeqByte("088002"))
    # echo 'x: 0xFFFF0000' | protoc --encode=PInt64Obj test_truncation.proto | hexdump -ve '1/1 "%.2x"'
    # 088080fcff0f
    # echo "088080fcff0f" | xxd -r -p | protoc --decode=BoolObj test_truncation.proto
    roundtrip(PInt64Obj(x: 0xFFFF0000'i64), BoolObj(x: true), hexToSeqByte("088080fcff0f"))

suite "Test sint64 to sint32 zig-zag":
  test "In-range sint64 is compatible with sint32":
    # echo 'x: 1' | protoc --encode=SInt64Obj test_truncation.proto | hexdump -ve '1/1 "%.2x"'
    # echo "0802" | xxd -r -p | protoc --decode=SInt32Obj test_truncation.proto
    # x: 1
    roundtrip(SInt64Obj(x: 1'i64), SInt32Obj(x: 1'i32), hexToSeqByte("0802"))
    roundtrip(SInt64Obj(x: 2'i64), SInt32Obj(x: 2'i32), hexToSeqByte("0804"))
    roundtrip(SInt64Obj(x: 3'i64), SInt32Obj(x: 3'i32), hexToSeqByte("0806"))
    roundtrip(SInt32Obj(x: 1'i32), SInt64Obj(x: 1'i64), hexToSeqByte("0802"))
    roundtrip(SInt32Obj(x: 2'i32), SInt64Obj(x: 2'i64), hexToSeqByte("0804"))
    roundtrip(SInt32Obj(x: 3'i32), SInt64Obj(x: 3'i64), hexToSeqByte("0806"))
    roundtrip(SInt64Obj(x: -1'i64), SInt32Obj(x: -1'i32), hexToSeqByte("0801"))
    roundtrip(SInt64Obj(x: -2'i64), SInt32Obj(x: -2'i32), hexToSeqByte("0803"))
    roundtrip(SInt64Obj(x: -3'i64), SInt32Obj(x: -3'i32), hexToSeqByte("0805"))
    roundtrip(SInt32Obj(x: -1'i32), SInt64Obj(x: -1'i64), hexToSeqByte("0801"))
    roundtrip(SInt32Obj(x: -2'i32), SInt64Obj(x: -2'i64), hexToSeqByte("0803"))
    roundtrip(SInt32Obj(x: -3'i32), SInt64Obj(x: -3'i64), hexToSeqByte("0805"))
    roundtrip(SInt64Obj(x: int32.high), SInt32Obj(x: int32.high), hexToSeqByte("08feffffff0f"))
    roundtrip(SInt32Obj(x: int32.high), SInt64Obj(x: int32.high), hexToSeqByte("08feffffff0f"))
    roundtrip(SInt64Obj(x: int32.low), SInt32Obj(x: int32.low), hexToSeqByte("08ffffffff0f"))
    roundtrip(SInt32Obj(x: int32.low), SInt64Obj(x: int32.low), hexToSeqByte("08ffffffff0f"))

  test "Out-of-range sint64 is truncated to sint32":
    # echo 'x: 2147483648' | protoc --encode=SInt64Obj test_truncation.proto | hexdump -ve '1/1 "%.2x"'
    # echo "088080808010" | xxd -r -p | protoc --decode=SInt32Obj test_truncation.proto
    roundtrip(SInt64Obj(x: int64(int32.high) + 1), SInt32Obj(x: 0'i32), hexToSeqByte("088080808010"))
    roundtrip(SInt64Obj(x: int64(int32.high) + 2), SInt32Obj(x: 1'i32), hexToSeqByte("088280808010"))
    roundtrip(SInt64Obj(x: int64(int32.high) + 3), SInt32Obj(x: 2'i32), hexToSeqByte("088480808010"))
    roundtrip(SInt64Obj(x: int64(int32.low) - 1), SInt32Obj(x: -1'i32), hexToSeqByte("088180808010"))
    roundtrip(SInt64Obj(x: int64(int32.low) - 2), SInt32Obj(x: -2'i32), hexToSeqByte("088380808010"))
    roundtrip(SInt64Obj(x: int64(int32.low) - 3), SInt32Obj(x: -3'i32), hexToSeqByte("088580808010"))
    roundtrip(SInt64Obj(x: int64.high), SInt32Obj(x: int32.high), hexToSeqByte("08feffffffffffffffff01"))
    roundtrip(SInt64Obj(x: int64.low), SInt32Obj(x: int32.low), hexToSeqByte("08ffffffffffffffffff01"))

suite "Test incompatible types":
  test "uint64 to sint64":
    # echo 'x: 0xFFFFFFFFFFFFFFFF' | protoc --encode=PUInt64Obj test_truncation.proto | hexdump -ve '1/1 "%.2x"'
    # 08ffffffffffffffffff01
    # echo "08ffffffffffffffffff01" | xxd -r -p | protoc --decode=SInt64Obj test_truncation.proto
    # x: int64.low
    roundtrip(PUInt64Obj(x: uint64.high), SInt64Obj(x: int64.low), hexToSeqByte("08ffffffffffffffffff01"))
