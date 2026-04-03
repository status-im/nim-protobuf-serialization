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
  Dummy {.proto3.} = object

suite "Test Group Decoding":
  test "decode start group is not supported":
    let encoded = @[byte(0x0B)]
    expect(ProtobufGroupError):
      discard Protobuf.decode(encoded, Dummy)
    expect(ProtobufValueError):
      discard Protobuf.decode(encoded, Dummy)

  test "decode end group is not supported":
    let encoded = @[byte(0x0C)]
    expect(ProtobufGroupError):
      discard Protobuf.decode(encoded, Dummy)
    expect(ProtobufValueError):
      discard Protobuf.decode(encoded, Dummy)
