# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2

import ./utils, ../protobuf_serialization

type
  PIntType {.proto3.} = object
    x {.fieldNumber: 1, pint.}: int32

  UIntType {.proto3.} = object
    x {.fieldNumber: 1, pint.}: uint32

  SIntType {.proto3.} = object
    x {.fieldNumber: 1, sint.}: int32

  BoolType {.proto3.} = object
    x {.fieldNumber: 1.}: bool

suite "Test Boolean Encoding/Decoding":
  test "Can encode/decode boolean without subtype specification":
    # echo "0801" | xxd -r -p | protoc --decode=BoolType test_bool.proto
    # x: true
    # echo "x: true" | protoc --encode=BoolType test_bool.proto | hexdump -ve '1/1 "%.2x"'
    # 0801
    roundtrip(BoolType(x: true), BoolType(x: true), "0801")
    roundtrip(BoolType(x: false), BoolType(x: false), "")

  #Skipping subtype specification only works when every encoding has the same truthiness.
  #That's what this tests. It should be noted 1 encodes as 1/1/2 for the following.
  test "Can encode/decode boolean as signed VarInt":
    # echo "x: 1" | protoc --encode=PIntType test_bool.proto | hexdump -ve '1/1 "%.2x"'
    # 0801
    roundtrip(PIntType(x: 1), BoolType(x: true), "0801")
    roundtrip(PIntType(x: 0), BoolType(x: false), "")

  test "Can encode/decode boolean as unsigned VarInt":
    # echo "x: 1" | protoc --encode=UIntType test_bool.proto | hexdump -ve '1/1 "%.2x"'
    # 0801
    roundtrip(UIntType(x: 1), BoolType(x: true), "0801")
    roundtrip(UIntType(x: 0), BoolType(x: false), "")

  test "Can encode/decode boolean as zig-zagged VarInt":
    # echo "x: 1" | protoc --encode=SIntType test_bool.proto | hexdump -ve '1/1 "%.2x"'
    # 0802
    # echo "0802" | xxd -r -p | protoc --decode=BoolType test_bool.proto
    # x: true
    roundtrip(SIntType(x: 1), BoolType(x: true), "0802")
    roundtrip(SIntType(x: 0), BoolType(x: false), "")
