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
  ../protobuf_serialization/pkg/results

type
  FewOptions {.proto2.} = object
    a {.fieldNumber: 1, pint.}: Opt[int32]
    b {.fieldNumber: 2, pint.}: Opt[int32]

  FullOfDefaults {.proto2.} = object
    a {.fieldNumber: 3.}: Opt[string]
    b {.fieldNumber: 4.}: Opt[FewOptions]

suite "Test results Opt[T]":
  test "sets optional valid field":
    # echo 'b: { b: 5 }' | protoc --encode=FullOfDefaults test_protobuf2_semantics.proto | hexdump -ve '1/1 "%.2x"'
    # 22021005
    roundtrip(FullOfDefaults(b: Opt.some(FewOptions(b: Opt.some(5'i32)))), "22021005")

  test "unexpected type does not set Opt":
    # echo "0801" | xxd -r -p | protoc --decode=FixedOption test_protobuf2_semantics.proto
    # 1: 1
    let encoded = "0801".hexToSeqByte
    check Protobuf.decode(encoded, FullOfDefaults) == FullOfDefaults()
