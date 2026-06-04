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
  Kind1 {.pure.} = enum
    unset
    x
    y

  OneOf1 {.proto3, oneof.} = object
    case kind: Kind1
    of Kind1.unset:
      discard
    of Kind1.x:
      x {.fieldNumber: 1, pint.}: int64
    of Kind1.y:
      y {.fieldNumber: 2, pint.}: int64

  Obj1 {.proto3.} = object
    one {.oneof.}: OneOf1

suite "Test oneof":
  test "oneof unset":
    let encoded = "".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj1)
    check:
      ret.one.kind == Kind1.unset
      Protobuf.encode(ret) == encoded

  test "oneof field 1 set to default":
    let encoded = "0800".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj1)
    check:
      ret.one.kind == Kind1.x
      ret.one.x == 0
      Protobuf.encode(ret) == encoded

  test "oneof field 1 set":
    # echo 'x: 1' | protoc --encode=OneOfObj test_oneof.proto | hexdump -ve '1/1 "%.2x"'
    # 0801
    let encoded = "0801".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj1)
    check:
      ret.one.kind == Kind1.x
      ret.one.x == 1
      Protobuf.encode(ret) == encoded

  test "oneof field 2 set":
    let encoded = "1001".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj1)
    check:
      ret.one.kind == Kind1.y
      ret.one.y == 1
      Protobuf.encode(ret) == encoded

  test "oneof field 1 and 2 set":
    let encoded = "08011001".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj1)
    check:
      ret.one.kind == Kind1.y
      ret.one.y == 1

  test "oneof field 1 and 2 set variant":
    let encoded = "10010801".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj1)
    check:
      ret.one.kind == Kind1.x
      ret.one.x == 1

type
  OneOf2 {.proto3, oneof.} = object
    case kind: Kind1
    of Kind1.unset:
      discard
    of Kind1.x:
      x {.fieldNumber: 3, pint.}: int64
    of Kind1.y:
      y {.fieldNumber: 4, pint.}: int64

  Obj2 {.proto3.} = object
    one {.oneof.}: OneOf1
    two {.oneof.}: OneOf2

suite "Test many oneof":
  test "many oneof unset":
    let encoded = "".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj2)
    check:
      ret.one.kind == Kind1.unset
      ret.two.kind == Kind1.unset
      Protobuf.encode(ret) == encoded

  test "many oneof field 1 set to default":
    let encoded = "0800".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj2)
    check:
      ret.one.kind == Kind1.x
      ret.one.x == 0
      ret.two.kind == Kind1.unset
      Protobuf.encode(ret) == encoded

  test "many oneof field 1 set":
    let encoded = "0801".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj2)
    check:
      ret.one.kind == Kind1.x
      ret.one.x == 1
      ret.two.kind == Kind1.unset
      Protobuf.encode(ret) == encoded

  test "many oneof field 3 set to default":
    let encoded = "1800".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj2)
    check:
      ret.one.kind == Kind1.unset
      ret.two.kind == Kind1.x
      ret.two.x == 0
      Protobuf.encode(ret) == encoded

  test "many oneof field 3 set":
    let encoded = "1801".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj2)
    check:
      ret.one.kind == Kind1.unset
      ret.two.kind == Kind1.x
      ret.two.x == 1
      Protobuf.encode(ret) == encoded

  test "many oneof field 1 and 3 set":
    let encoded = "08011801".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj2)
    check:
      ret.one.kind == Kind1.x
      ret.one.x == 1
      ret.two.kind == Kind1.x
      ret.two.x == 1
      Protobuf.encode(ret) == encoded

  test "many oneof field 1 and 3 set to default":
    let encoded = "08001800".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj2)
    check:
      ret.one.kind == Kind1.x
      ret.one.x == 0
      ret.two.kind == Kind1.x
      ret.two.x == 0
      Protobuf.encode(ret) == encoded

  test "many oneof field 1 and 3 set variant":
    let encoded = "1001200108011801".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj2)
    check:
      ret.one.kind == Kind1.x
      ret.one.x == 1
      ret.two.kind == Kind1.x
      ret.two.x == 1

  test "many oneof field 2 and 4 set to default":
    let encoded = "10002000".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj2)
    check:
      ret.one.kind == Kind1.y
      ret.one.y == 0
      ret.two.kind == Kind1.y
      ret.two.y == 0
      Protobuf.encode(ret) == encoded

  test "many oneof field 2 and 4 set":
    let encoded = "10012001".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj2)
    check:
      ret.one.kind == Kind1.y
      ret.one.y == 1
      ret.two.kind == Kind1.y
      ret.two.y == 1
      Protobuf.encode(ret) == encoded

  test "many oneof field 2 and 4 set variant":
    let encoded = "0801180110012001".hexToSeqByte
    let ret = Protobuf.decode(encoded, Obj2)
    check:
      ret.one.kind == Kind1.y
      ret.one.y == 1
      ret.two.kind == Kind1.y
      ret.two.y == 1
