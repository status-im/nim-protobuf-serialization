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
    # echo 'b: { b: 5 }' | protoc --encode=FullOfDefaults test_pkg_results_2.proto | hexdump -ve '1/1 "%.2x"'
    # 22021005
    roundtrip(FullOfDefaults(b: Opt.some(FewOptions(b: Opt.some(5'i32)))), "22021005")

  test "proto2 unexpected type does not set Opt":
    # echo "0801" | xxd -r -p | protoc --decode=FullOfDefaults test_pkg_results_2.proto
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

  test "proto2 optional message merging":
    # 22020801 -> b: {a: 1}
    # 1a03616263 -> a: "abc" (split)
    # 22021001 -> b: {b: 1}
    # echo "220208011a0361626322021001" | xxd -r -p | protoc --decode=FullOfDefaults test_pkg_results_2.proto
    # a: "abc"
    # b {
    #   a: 1
    #   b: 1
    # }
    let encoded = "220208011a0361626322021001".hexToSeqByte
    check Protobuf.decode(encoded, FullOfDefaults) ==
      FullOfDefaults(a: Opt.some("abc"), b: Opt.some(FewOptions(a: Opt.some(1'i32), b: Opt.some(1'i32))))

  test "proto2 optional message merging overwrite":
    # 22020801 -> b: {a: 1}
    # 22021001 -> b: {b: 1}
    # 22020802 -> b: {a: 2}
    # echo "220208012202100122020802" | xxd -r -p | protoc --decode=FullOfDefaults test_pkg_results_2.proto
    # b {
    #   a: 2
    #   b: 1
    # }
    let encoded = "220208012202100122020802".hexToSeqByte
    check Protobuf.decode(encoded, FullOfDefaults) ==
      FullOfDefaults(b: Opt.some(FewOptions(a: Opt.some(2'i32), b: Opt.some(1'i32))))

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

  test "proto3 optional message merging":
    # 22020801 -> b: {a: 1}
    # 1a03616263 -> a: "abc" (split)
    # 22021001 -> b: {b: 1}
    # echo "220208011a0361626322021001" | xxd -r -p | protoc --decode=P3FullOfDefaults test_pkg_results_3.proto
    # a: "abc"
    # b {
    #   a: 1
    #   b: 1
    # }
    let encoded = "220208011a0361626322021001".hexToSeqByte
    check Protobuf.decode(encoded, P3FullOfDefaults) ==
      P3FullOfDefaults(a: Opt.some("abc"), b: Opt.some(P3FewOptions(a: Opt.some(1'i32), b: Opt.some(1'i32))))

  test "proto3 optional message merging overwrite":
    # 22020801 -> b: {a: 1}
    # 22021001 -> b: {b: 1}
    # 22020802 -> b: {a: 2}
    # echo "220208012202100122020802" | xxd -r -p | protoc --decode=FullOfDefaults test_pkg_results_2.proto
    # b {
    #   a: 2
    #   b: 1
    # }
    let encoded = "220208012202100122020802".hexToSeqByte
    check Protobuf.decode(encoded, P3FullOfDefaults) ==
      P3FullOfDefaults(b: Opt.some(P3FewOptions(a: Opt.some(2'i32), b: Opt.some(1'i32))))
