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
  ../protobuf_serialization/std/enums,
  ../protobuf_serialization/pkg/results

type
  Classic = enum
    A1
    B1
    C1

  ObjClassicOptP2 {.proto2.} = object
    x {.fieldNumber: 1, ext.}: Opt[Classic]

suite "Test Opt[enum] Encoding/Decoding":
  test "proto2 optional enum":
    # pbNone: field absent, encodes to empty
    roundtrip(ObjClassicOptP2(x: Opt.none(Classic)), "")
    # pbSome: field present, encoded even when value matches the default int (0)
    roundtrip(ObjClassicOptP2(x: Opt.some(A1)), "0800")
    roundtrip(ObjClassicOptP2(x: Opt.some(B1)), "0801")
    roundtrip(ObjClassicOptP2(x: Opt.some(C1)), "0802")

  test "proto2 optional enum invalid":
    # echo "0803" | xxd -r -p | protoc --decode=ObjClassicOptP2 test_std_enums_2.proto
    # 1: 3
    let encoded = "0803".hexToSeqByte
    check Protobuf.decode(encoded, ObjClassicOptP2) == ObjClassicOptP2(x: Opt.none(Classic))

  test "proto2 optional enum + invalid":
    # echo "08010803" | xxd -r -p | protoc --decode=ObjClassicOptP2 test_std_enums_2.proto
    # x: B1
    # 1: 3
    block:
      let encoded = "08010803".hexToSeqByte
      check Protobuf.decode(encoded, ObjClassicOptP2) == ObjClassicOptP2(x: Opt.some(B1))
    block:
      let encoded = "08030801".hexToSeqByte
      check Protobuf.decode(encoded, ObjClassicOptP2) == ObjClassicOptP2(x: Opt.some(B1))
