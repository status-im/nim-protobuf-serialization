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

  P3FewOptions {.proto3.} = object
    a {.fieldNumber: 1, pint.}: Opt[int32]
    b {.fieldNumber: 2, pint.}: Opt[int32]

  P3FullOfDefaults {.proto3.} = object
    a {.fieldNumber: 3.}: Opt[string]
    b {.fieldNumber: 4.}: Opt[P3FewOptions]

suite "Test results Opt[T]":
  test "proto2 sets optional valid field":
    # echo 'b: { b: 5 }' | protoc --encode=FullOfDefaults test_protobuf2_semantics.proto | hexdump -ve '1/1 "%.2x"'
    # 22021005
    roundtrip(FullOfDefaults(b: Opt.some(FewOptions(b: Opt.some(5'i32)))), "22021005")

  test "proto2 unexpected type does not set Opt":
    # echo "0801" | xxd -r -p | protoc --decode=FullOfDefaults test_protobuf2_semantics.proto
    # 1: 1
    let encoded = "0801".hexToSeqByte
    check Protobuf.decode(encoded, FullOfDefaults) == FullOfDefaults()

  test "proto2 optional default":
    # echo 'a: 0' | protoc --encode=FewOptions test_pkg_results_2.proto | hexdump -ve '1/1 "%.2x"'
    # 0800
    # echo "0800" | xxd -r -p | protoc --decode=FewOptions test_pkg_results_2.proto
    # a: 0
    roundtrip(FewOptions(a: Opt.some(0'i32)), "0800")

  test "proto2 optional set":
    # echo 'a: 1' | protoc --encode=FewOptions test_pkg_results_2.proto | hexdump -ve '1/1 "%.2x"'
    # 0801
    # echo "0801" | xxd -r -p | protoc --decode=FewOptions test_pkg_results_2.proto
    # a: 1
    roundtrip(FewOptions(a: Opt.some(1'i32)), "0801")

  test "proto3 sets optional valid field":
    # echo 'b: { b: 5 }' | protoc --encode=P3FullOfDefaults test_pkg_results_3.proto | hexdump -ve '1/1 "%.2x"'
    # 22021005
    roundtrip(P3FullOfDefaults(b: Opt.some(P3FewOptions(b: Opt.some(5'i32)))), "22021005")

  test "proto3 unexpected type does not set Opt":
    # echo "0801" | xxd -r -p | protoc --decode=P3FullOfDefaults test_pkg_results_3.proto
    # 1: 1
    let encoded = "0801".hexToSeqByte
    check Protobuf.decode(encoded, P3FullOfDefaults) == P3FullOfDefaults()

  test "proto3 optional default":
    # echo 'a: 0' | protoc --encode=P3FewOptions test_pkg_results_3.proto | hexdump -ve '1/1 "%.2x"'
    # 0800
    # echo "0800" | xxd -r -p | protoc --decode=P3FewOptions test_pkg_results_3.proto
    # a: 0
    roundtrip(P3FewOptions(a: Opt.some(0'i32)), "0800")

  test "proto3 optional set":
    # echo 'a: 1' | protoc --encode=P3FewOptions test_pkg_results_3.proto | hexdump -ve '1/1 "%.2x"'
    # 0801
    # echo "0801" | xxd -r -p | protoc --decode=P3FewOptions test_pkg_results_3.proto
    # a: 1
    roundtrip(P3FewOptions(a: Opt.some(1'i32)), "0801")
