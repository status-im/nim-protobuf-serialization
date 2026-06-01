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
import ../protobuf_serialization

type
  OneOfKind {.pure.} = enum
    unset
    x
    y

  OneOfObj {.proto3.} = object
    one {.oneof, dontSerialize.}: OneOfKind
    x {.fieldNumber: 1, pint.}: int64
    y {.fieldNumber: 2, pint.}: int64

suite "Test oneof":
  test "oneof unset":
    let encoded = "".hexToSeqByte
    check Protobuf.decode(encoded, OneOfObj) == OneOfObj(one: OneOfKind.unset)

  test "oneof field 1 set":
    # echo 'x: 1' | protoc --encode=OneOfObj test_oneof.proto | hexdump -ve '1/1 "%.2x"'
    # 0801
    let encoded = "0801".hexToSeqByte
    check Protobuf.decode(encoded, OneOfObj) == OneOfObj(one: OneOfKind.x, x: 1)

  test "oneof field 2 set":
    let encoded = "1001".hexToSeqByte
    check Protobuf.decode(encoded, OneOfObj) == OneOfObj(one: OneOfKind.y, y: 1)

  test "oneof field 1 and 2 set":
    let encoded = "08011001".hexToSeqByte
    check Protobuf.decode(encoded, OneOfObj) == OneOfObj(one: OneOfKind.y, y: 1)

  test "oneof field 1 and 2 set variant":
    let encoded = "10010801".hexToSeqByte
    check Protobuf.decode(encoded, OneOfObj) == OneOfObj(one: OneOfKind.x, x: 1)

type
  OneOfKind1 {.pure.} = enum
    unset
    a
    b

  OneOfKind2 {.pure.} = enum
    unset
    c
    d

  OneOfManyObj {.proto3.} = object
    one {.oneof, dontSerialize.}: OneOfKind1
    a {.fieldNumber: 1, pint.}: int64
    b {.fieldNumber: 2, pint.}: int64
    two {.oneof, dontSerialize.}: OneOfKind2
    c {.fieldNumber: 3, pint.}: int64
    d {.fieldNumber: 4, pint.}: int64

suite "Test many oneof":
  test "many oneof unset":
    let encoded = "".hexToSeqByte
    check Protobuf.decode(encoded, OneOfManyObj) ==
      OneOfManyObj(one: OneOfKind1.unset, two: OneOfKind2.unset)

  test "many oneof field 1 set":
    let encoded = "0801".hexToSeqByte
    check Protobuf.decode(encoded, OneOfManyObj) == OneOfManyObj(
      one: OneOfKind1.a, a: 1
    )

  test "many oneof field 3 set":
    let encoded = "1801".hexToSeqByte
    check Protobuf.decode(encoded, OneOfManyObj) == OneOfManyObj(
      two: OneOfKind2.c, c: 1
    )

  test "many oneof field 1 and 3 set":
    let encoded = "08011801".hexToSeqByte
    check Protobuf.decode(encoded, OneOfManyObj) ==
      OneOfManyObj(one: OneOfKind1.a, a: 1, two: OneOfKind2.c, c: 1)

  test "many oneof field 1 and 3 set variant":
    let encoded = "1001200108011801".hexToSeqByte
    check Protobuf.decode(encoded, OneOfManyObj) ==
      OneOfManyObj(one: OneOfKind1.a, a: 1, two: OneOfKind2.c, c: 1)

  test "many oneof field 2 and 4 set":
    let encoded = "10012001".hexToSeqByte
    check Protobuf.decode(encoded, OneOfManyObj) ==
      OneOfManyObj(one: OneOfKind1.b, b: 1, two: OneOfKind2.d, d: 1)

  test "many oneof field 2 and 4 set variant":
    let encoded = "0801180110012001".hexToSeqByte
    check Protobuf.decode(encoded, OneOfManyObj) ==
      OneOfManyObj(one: OneOfKind1.b, b: 1, two: OneOfKind2.d, d: 1)
