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
  OneOf {.proto3.} = object
    kind {.dontSerialize.}: OneOfKind
    x {.fieldNumber: 1, pint.}: int64
    y {.fieldNumber: 2, pint.}: int64
  OneOfObj {.proto3.} = object
    one {.oneof, dontSerialize.}: OneOf

suite "Test oneof":
  test "oneof unset":
    let encoded = "".hexToSeqByte
    check Protobuf.decode(encoded, OneOfObj) == OneOfObj(one: OneOf(kind: OneOfKind.unset))

  test "oneof field 1 set":
    # echo 'x: 1' | protoc --encode=OneOfObj test_oneof.proto | hexdump -ve '1/1 "%.2x"'
    # 0801
    let encoded = "0801".hexToSeqByte
    check Protobuf.decode(encoded, OneOfObj) == OneOfObj(one: OneOf(kind: OneOfKind.x, x: 1))

  test "oneof field 2 set":
    let encoded = "1001".hexToSeqByte
    check Protobuf.decode(encoded, OneOfObj) == OneOfObj(one: OneOf(kind: OneOfKind.y, y: 1))

  test "oneof field 1 and 2 set":
    let encoded = "08011001".hexToSeqByte
    check Protobuf.decode(encoded, OneOfObj) == OneOfObj(one: OneOf(kind: OneOfKind.y, y: 1))

  test "oneof field 1 and 2 set variant":
    let encoded = "10010801".hexToSeqByte
    check Protobuf.decode(encoded, OneOfObj) == OneOfObj(one: OneOf(kind: OneOfKind.x, x: 1))
