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

type
  KindAll {.pure.} = enum
    unset
    x01
    x02
    x03
    x04
    x05
    x06
    x07
    x08
    x09
    x10
    x11
    x12
    x13
    x14
    x15

  SomeMessage {.proto3.} = object
    x {.fieldNumber: 1, pint.}: int32
    y {.fieldNumber: 2, pint.}: int32

  OneOfAll {.proto3, oneof.} = object
    case kind: KindAll
    of KindAll.unset:
      discard
    of KindAll.x01:
      x01 {.fieldNumber: 1.}: string
    of KindAll.x02:
      x02 {.fieldNumber: 2.}: seq[byte]
    of KindAll.x03:
      x03 {.fieldNumber: 3, pint.}: int32
    of KindAll.x04:
      x04 {.fieldNumber: 4, pint.}: uint32
    of KindAll.x05:
      x05 {.fieldNumber: 5, pint.}: int64
    of KindAll.x06:
      x06 {.fieldNumber: 6, pint.}: uint64
    of KindAll.x07:
      x07 {.fieldNumber: 7, sint.}: int32
    of KindAll.x08:
      x08 {.fieldNumber: 8, sint.}: int64
    of KindAll.x09:
      x09 {.fieldNumber: 9, fixed.}: int32
    of KindAll.x10:
      x10 {.fieldNumber: 10, fixed.}: int64
    of KindAll.x11:
      x11 {.fieldNumber: 11, fixed.}: uint32
    of KindAll.x12:
      x12 {.fieldNumber: 12, fixed.}: uint64
    of KindAll.x13:
      x13 {.fieldNumber: 13.}: float32
    of KindAll.x14:
      x14 {.fieldNumber: 14.}: float64
    of KindAll.x15:
      x15 {.fieldNumber: 15.}: SomeMessage

  ObjAll {.proto3.} = object
    one {.oneof.}: OneOfAll

suite "Test all types in oneof":
  test "all oneof unset":
    let encoded = "".hexToSeqByte
    let ret = Protobuf.decode(encoded, ObjAll)
    check:
      ret.one.kind == KindAll.unset
      Protobuf.encode(ret) == encoded

  test "string oneof set":
    let encoded = "0a03616263".hexToSeqByte
    let ret = Protobuf.decode(encoded, ObjAll)
    check:
      ret.one.kind == KindAll.x01
      ret.one.x01 == "abc"
      Protobuf.encode(ret) == encoded

  test "bytes oneof set":
    let encoded = "120101".hexToSeqByte
    let ret = Protobuf.decode(encoded, ObjAll)
    check:
      ret.one.kind == KindAll.x02
      ret.one.x02 == @[0x01'u8]
      Protobuf.encode(ret) == encoded

  test "pint int32 oneof set":
    let encoded = "187b".hexToSeqByte
    let ret = Protobuf.decode(encoded, ObjAll)
    check:
      ret.one.kind == KindAll.x03
      ret.one.x03 == 123
      Protobuf.encode(ret) == encoded

  test "sint int32 oneof set":
    let encoded = "38f601".hexToSeqByte
    let ret = Protobuf.decode(encoded, ObjAll)
    check:
      ret.one.kind == KindAll.x07
      ret.one.x07 == 123
      Protobuf.encode(ret) == encoded

  test "fixed int32 oneof set":
    let encoded = "4d7b000000".hexToSeqByte
    let ret = Protobuf.decode(encoded, ObjAll)
    check:
      ret.one.kind == KindAll.x09
      ret.one.x09 == 123
      Protobuf.encode(ret) == encoded

  test "message default oneof set":
    # echo 'x15: {}' | protoc --encode=ObjAll test_oneof.proto | hexdump -ve '1/1 "%.2x"'
    # 7a00
    let encoded = "7a00".hexToSeqByte
    let ret = Protobuf.decode(encoded, ObjAll)
    check:
      ret.one.kind == KindAll.x15
      ret.one.x15 == SomeMessage()
      Protobuf.encode(ret) == encoded

  test "message oneof set":
    # echo 'x15: {x: 1}' | protoc --encode=ObjAll test_oneof.proto | hexdump -ve '1/1 "%.2x"'
    # 7a020801
    let encoded = "7a020801".hexToSeqByte
    let ret = Protobuf.decode(encoded, ObjAll)
    check:
      ret.one.kind == KindAll.x15
      ret.one.x15 == SomeMessage(x: 1)
      Protobuf.encode(ret) == encoded

  test "oneof message merge":
    # d80701 is "123: 1" and splits the message
    # echo "7a020801d807017a021001" | xxd -r -p | protoc --decode=ObjAll test_oneof.proto
    # x15 {
    #   x: 1
    #   y: 1
    # }
    # 123: 1
    # echo 'x15: {x: 1 y: 1}' | protoc --encode=ObjAll test_oneof.proto | hexdump -ve '1/1 "%.2x"'
    # 7a0408011001
    let encoded = "7a020801d807017a021001".hexToSeqByte
    let ret = Protobuf.decode(encoded, ObjAll)
    check:
      ret.one.kind == KindAll.x15
      ret.one.x15 == SomeMessage(x: 1, y: 1)
      Protobuf.encode(ret) == "7a0408011001".hexToSeqByte

  test "oneof message no merge":
    # 7a020801 -> x15: {x: 1}
    # 187b -> x03: 123
    # 7a021001 -> x15: {y: 1}
    # echo "7a020801187b7a021001" | xxd -r -p | protoc --decode=ObjAll test_oneof.proto
    # x15 {
    #   y: 1
    # }
    let encoded = "7a020801187b7a021001".hexToSeqByte
    let ret = Protobuf.decode(encoded, ObjAll)
    check:
      ret.one.kind == KindAll.x15
      ret.one.x15 == SomeMessage(y: 1)
      Protobuf.encode(ret) == "7a021001".hexToSeqByte
