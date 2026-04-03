# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2

import ../protobuf_serialization

type
  Empty {.proto3.} = object

  Bytes {.proto3.} = object
    x {.fieldNumber: 1.}: seq[byte]

  AllDefaults {.proto3.} = object
    x01 {.fieldNumber: 1.}: seq[byte]
    x02 {.fieldNumber: 2.}: string
    x03 {.fieldNumber: 3, pint.}: int32
    x04 {.fieldNumber: 4, pint.}: uint32
    x05 {.fieldNumber: 5, pint.}: int64
    x06 {.fieldNumber: 6, pint.}: uint64
    x07 {.fieldNumber: 7, sint.}: int32
    x08 {.fieldNumber: 8, sint.}: int64
    x09 {.fieldNumber: 9, fixed.}: int32
    x10 {.fieldNumber: 10, fixed.}: int64
    x11 {.fieldNumber: 11.}: float64
    x12 {.fieldNumber: 12.}: float32
    x13 {.fieldNumber: 13.}: bool
    x14 {.fieldNumber: 14.}: Bytes

suite "Test Encoding of Empty Objects/Values":
  test "Empty object":
    check Protobuf.encode(Empty()).len == 0

  test "All default values produce no output":
    check Protobuf.encode(AllDefaults()).len == 0
