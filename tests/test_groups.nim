import unittest2

import ../protobuf_serialization

type
  Dummy {.proto3.} = object

suite "Test Group Decoding":
  test "decode start group is not supported":
    let encoded = @[byte(0x0B)]
    expect(ProtobufUnsupportedWireTypeError):
      discard Protobuf.decode(encoded, Dummy)
    expect(ProtobufValueError):
      discard Protobuf.decode(encoded, Dummy)

  test "decode end group is not supported":
    let encoded = @[byte(0x0C)]
    expect(ProtobufUnsupportedWireTypeError):
      discard Protobuf.decode(encoded, Dummy)
    expect(ProtobufValueError):
      discard Protobuf.decode(encoded, Dummy)
