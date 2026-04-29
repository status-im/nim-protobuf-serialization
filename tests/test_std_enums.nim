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
  ../protobuf_serialization,
  ../protobuf_serialization/std/enums

type
  Classic = enum
    A1
    B1
    C1

  WithHoles = enum
    A2 = -10
    B2 = 0
    C2 = 10
    D2

  Limits = enum
    A3 = int32.low()
    B3 = 0
    C3 = int32.high()

  ObjClassicP2 {.proto2.} = object
    x {.fieldNumber: 1, required, ext.}: Classic

  ObjWithHolesP2 {.proto2.} = object
    x {.fieldNumber: 1, required, ext.}: WithHoles

  ObjLimitsP2 {.proto2.} = object
    x {.fieldNumber: 1, required, ext.}: Limits

  ObjClassicOptP2 {.proto2.} = object
    x {.fieldNumber: 1, ext.}: PBOption[default(Classic)]

  ObjClassicP3 {.proto3.} = object
    x {.fieldNumber: 1, ext.}: Classic

  ObjWithHolesP3 {.proto3.} = object
    x {.fieldNumber: 1, ext.}: WithHoles

  ObjLimitsP3 {.proto3.} = object
    x {.fieldNumber: 1, ext.}: Limits

suite "Test Enum Encoding/Decoding":
  test "ordinal enum valid values":
    # echo "0800" | xxd -r -p | protoc --decode=ObjClassicP2 test_std_enums_2.proto
    # echo 'x: 0' | protoc --encode=ObjClassicP2 test_std_enums_2.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(ObjClassicP2(x: A1), "0800")
    roundtrip(ObjClassicP2(x: B1), "0801")
    roundtrip(ObjClassicP2(x: C1), "0802")

  test "ordinal enum invalid values":
    # echo "0803" | xxd -r -p | protoc --decode=ObjClassicP2 test_std_enums_2.proto
    # warning:  Input message is missing required fields:  x
    # 1: 3
    let encoded = "0803".hexToSeqByte
    expect(ProtobufReadError):
      discard ProtoBuf.decode(encoded, ObjClassicP2)
