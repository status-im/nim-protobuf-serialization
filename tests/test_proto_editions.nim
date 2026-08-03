# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  unittest2,
  stew/byteutils,
  ./utils,
  ../protobuf_serialization

type
  Mixed {.proto.} = object
    a {.fieldNumber: 1, pint.}: PBExplicit[0'i32]
    b {.fieldNumber: 2, pint, required.}: int32
    c {.fieldNumber: 3, pint, implicit.}: int32

  MixedWithImplicit {.proto, implicit.} = object
    a {.fieldNumber: 1, pint.}: PBExplicit[0'i32]
    b {.fieldNumber: 2, pint, required.}: int32
    c {.fieldNumber: 3, pint.}: int32

  Mixed2023 {.proto: 2023, implicit.} = object
    a {.fieldNumber: 1, pint.}: PBExplicit[0'i32]
    b {.fieldNumber: 2, pint, required.}: int32
    c {.fieldNumber: 3, pint.}: int32

  Mixed2024 {.proto: 2024, implicit.} = object
    a {.fieldNumber: 1, pint.}: PBExplicit[0'i32]
    b {.fieldNumber: 2, pint, required.}: int32
    c {.fieldNumber: 3, pint.}: int32

  Mixed2026 {.proto: 2026, implicit.} = object
    a {.fieldNumber: 1, pint.}: PBExplicit[0'i32]
    b {.fieldNumber: 2, pint, required.}: int32
    c {.fieldNumber: 3, pint.}: int32

  Packed {.proto.} = object
    a {.fieldNumber: 1, pint.}: seq[int32]

  NotPacked {.proto.} = object
    a {.fieldNumber: 1, pint, packed: false.}: seq[int32]

  MixedOpt {.proto.} = object
    a {.fieldNumber: 1, pint.}: PBExplicit[0'i32]
    c {.fieldNumber: 3, pint, implicit.}: int32

  Explicit {.proto.} = object
    a {.fieldNumber: 1, pint.}: PBExplicit[1'i32]

  AllTypesOpt {.proto, implicit.} = object
    x01 {.fieldNumber: 1.}: string
    x02 {.fieldNumber: 2.}: seq[byte]
    x03 {.fieldNumber: 3, pint.}: int32
    x04 {.fieldNumber: 4, pint.}: uint32
    x05 {.fieldNumber: 5, pint.}: int64
    x06 {.fieldNumber: 6, pint.}: uint64
    x07 {.fieldNumber: 7, sint.}: int32
    x08 {.fieldNumber: 8, sint.}: int64
    x09 {.fieldNumber: 9, fixed.}: int32
    x10 {.fieldNumber: 10, fixed.}: int64
    x11 {.fieldNumber: 11, fixed.}: uint32
    x12 {.fieldNumber: 12, fixed.}: uint64
    x13 {.fieldNumber: 13.}: float32
    x14 {.fieldNumber: 14.}: float64
    x15 {.fieldNumber: 15.}: MixedOpt
    x16 {.fieldNumber: 16.}: Explicit

suite "Test proto editions":
  test "all types":
    roundtrip(AllTypesOpt(), "")

  test "mixed":
    # echo 'b: 0' | protoc --encode=Mixed test_proto_editions.proto | hexdump -ve '1/1 "%.2x"'
    # echo "1000" | xxd -r -p | protoc --decode=Mixed test_proto_editions.proto
    roundtrip(Mixed(), "1000")
    roundtrip(MixedWithImplicit(), "1000")
    roundtrip(Mixed2023(), "1000")
    roundtrip(Mixed2024(), "1000")
    roundtrip(Mixed2026(), "1000")

  test "mixed optional":
    roundtrip(Mixed(a: pbSome(0'i32)), "08001000")
    # echo 'a: 1 b: 0' | protoc --encode=Mixed test_proto_editions.proto | hexdump -ve '1/1 "%.2x"'
    # echo "08011000" | xxd -r -p | protoc --decode=Mixed test_proto_editions.proto
    roundtrip(Mixed(a: pbSome(1'i32)), "08011000")
    roundtrip(MixedWithImplicit(a: pbSome(1'i32)), "08011000")
    roundtrip(Mixed2023(a: pbSome(1'i32)), "08011000")
    roundtrip(Mixed2024(a: pbSome(1'i32)), "08011000")
    roundtrip(Mixed2026(a: pbSome(1'i32)), "08011000")

  test "mixed required":
    # echo 'b: 1' | protoc --encode=Mixed test_proto_editions.proto | hexdump -ve '1/1 "%.2x"'
    # echo "1001" | xxd -r -p | protoc --decode=Mixed test_proto_editions.proto
    roundtrip(Mixed(b: 1'i32), "1001")
    roundtrip(MixedWithImplicit(b: 1'i32), "1001")
    roundtrip(Mixed2023(b: 1'i32), "1001")
    roundtrip(Mixed2024(b: 1'i32), "1001")
    roundtrip(Mixed2026(b: 1'i32), "1001")

  test "mixed implicit":
    # echo 'b: 0 c: 1' | protoc --encode=Mixed test_proto_editions.proto | hexdump -ve '1/1 "%.2x"'
    # echo "10001801" | xxd -r -p | protoc --decode=Mixed test_proto_editions.proto
    roundtrip(Mixed(c: 1'i32), "10001801")
    roundtrip(MixedWithImplicit(c: 1'i32), "10001801")
    roundtrip(Mixed2023(c: 1'i32), "10001801")
    roundtrip(Mixed2024(c: 1'i32), "10001801")
    roundtrip(Mixed2026(c: 1'i32), "10001801")

  test "mixed required empty":
    expect ProtobufReadError:
      discard Protobuf.decode(default(seq[byte]), Mixed)
    expect ProtobufReadError:
      discard Protobuf.decode(default(seq[byte]), MixedWithImplicit)
    expect ProtobufReadError:
      discard Protobuf.decode(default(seq[byte]), Mixed2023)
    expect ProtobufReadError:
      discard Protobuf.decode(default(seq[byte]), Mixed2024)
    expect ProtobufReadError:
      discard Protobuf.decode(default(seq[byte]), Mixed2026)

  test "packed":
    roundtrip(Packed(), "")

  test "not packed":
    roundtrip(NotPacked(), "")

  test "packed default":
    # echo 'a: [1, 2]' | protoc --encode=Packed test_proto_editions.proto | hexdump -ve '1/1 "%.2x"'
    # echo "0a020102" | xxd -r -p | protoc --decode=Packed test_proto_editions.proto
    roundtrip(Packed(a: @[1'i32, 2]), "0a020102")

  test "packed false":
    # echo 'a: [1, 2]' | protoc --encode=NotPacked test_proto_editions.proto | hexdump -ve '1/1 "%.2x"'
    # echo "0a020102" | xxd -r -p | protoc --decode=NotPacked test_proto_editions.proto
    roundtrip(NotPacked(a: @[1'i32, 2]), "08010802")

  test "explicit":
    roundtrip(Explicit(), "")
    roundtrip(Explicit(a: PBExplicit[1'i32].pbSome(0'i32)), "0800")
    roundtrip(Explicit(a: PBExplicit[1'i32].pbSome(1'i32)), "0801")
