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

  ObjRepeatedP2 {.proto2.} = object
    x {.fieldNumber: 1, ext.}: seq[Classic]

  ObjRepeatedPackedP2 {.proto2.} = object
    x {.fieldNumber: 1, ext, packed: true.}: seq[Classic]

  ObjClassicP3 {.proto3.} = object
    x {.fieldNumber: 1, ext.}: Classic

  ObjWithHolesP3 {.proto3.} = object
    x {.fieldNumber: 1, ext.}: WithHoles

  ObjLimitsP3 {.proto3.} = object
    x {.fieldNumber: 1, ext.}: Limits

  ObjRepeatedP3 {.proto3.} = object
    x {.fieldNumber: 1, ext.}: seq[Classic]

  ObjRepeatedUnpackedP3 {.proto3.} = object
    x {.fieldNumber: 1, ext, packed: false.}: seq[Classic]

suite "Test Enum Encoding/Decoding":
  test "proto2 ordinal enum valid values":
    # echo "0800" | xxd -r -p | protoc --decode=ObjClassicP2 test_std_enums_2.proto
    # echo 'x: 0' | protoc --encode=ObjClassicP2 test_std_enums_2.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(ObjClassicP2(x: A1), "0800")
    roundtrip(ObjClassicP2(x: B1), "0801")
    roundtrip(ObjClassicP2(x: C1), "0802")

  test "proto2 ordinal enum invalid values":
    # echo "0803" | xxd -r -p | protoc --decode=ObjClassicP2 test_std_enums_2.proto
    # warning:  Input message is missing required fields:  x
    # 1: 3
    let encoded = "0803".hexToSeqByte
    expect(ProtobufReadError):
      discard Protobuf.decode(encoded, ObjClassicP2)

  test "proto2 enum with holes valid values":
    # echo 'x: 0' | protoc --encode=ObjWithHolesP2 test_std_enums_2.proto | hexdump -ve '1/1 "%.2x"'
    # 0800
    roundtrip(ObjWithHolesP2(x: B2), "0800")
    # echo 'x: 10' | protoc --encode=ObjWithHolesP2 test_std_enums_2.proto | hexdump -ve '1/1 "%.2x"'
    # 080a
    roundtrip(ObjWithHolesP2(x: C2), "080a")
    roundtrip(ObjWithHolesP2(x: D2), "080b")
    # echo 'x: -10' | protoc --encode=ObjWithHolesP2 test_std_enums_2.proto | hexdump -ve '1/1 "%.2x"'
    # 08f6ffffffffffffffff01
    roundtrip(ObjWithHolesP2(x: A2), "08f6ffffffffffffffff01")

  test "proto2 enum with holes invalid values":
    # echo "0805" | xxd -r -p | protoc --decode=ObjWithHolesP2 test_std_enums_2.proto
    # warning:  Input message is missing required fields:  x
    # 1: 5
    let encoded = "0805".hexToSeqByte
    expect(ProtobufReadError):
      discard Protobuf.decode(encoded, ObjWithHolesP2)

  test "proto2 enum with int32 limits valid values":
    roundtrip(ObjLimitsP2(x: B3), "0800")
    # echo 'x: 2147483647' | protoc --encode=ObjLimitsP2 test_std_enums_2.proto | hexdump -ve '1/1 "%.2x"'
    # 08ffffffff07
    roundtrip(ObjLimitsP2(x: C3), "08ffffffff07")
    # echo 'x: -2147483648' | protoc --encode=ObjLimitsP2 test_std_enums_2.proto | hexdump -ve '1/1 "%.2x"'
    # 0880808080f8ffffffff01
    roundtrip(ObjLimitsP2(x: A3), "0880808080f8ffffffff01")

  test "proto2 enum with int32 limits invalid values":
    # 1 is not in {int32.low, 0, int32.high}
    let encoded = "0801".hexToSeqByte
    expect(ProtobufReadError):
      discard Protobuf.decode(encoded, ObjLimitsP2)

  test "proto2 optional enum":
    # pbNone: field absent, encodes to empty
    roundtrip(ObjClassicOptP2(x: pbNone(default(Classic))), "")
    # pbSome: field present, encoded even when value matches the default int (0)
    roundtrip(ObjClassicOptP2(x: pbSome(A1)), "0800")
    roundtrip(ObjClassicOptP2(x: pbSome(B1)), "0801")
    roundtrip(ObjClassicOptP2(x: pbSome(C1)), "0802")

  test "proto2 optional enum invalid":
    # echo "0803" | xxd -r -p | protoc --decode=ObjClassicOptP2 test_std_enums_2.proto
    # 1: 3
    let encoded = "0803".hexToSeqByte
    check Protobuf.decode(encoded, ObjClassicOptP2) == ObjClassicOptP2(x: pbNone(default(Classic)))

  test "proto2 repeated enum":
    # echo "080008010802" | xxd -r -p | protoc --decode=ObjRepeatedP2 test_std_enums_2.proto
    # echo 'x: 0 x: 1 x: 2' | protoc --encode=ObjRepeatedP2 test_std_enums_2.proto | hexdump -ve '1/1 "%.2x"'
    # roundtrip is unpacked for proto2
    roundtrip(ObjRepeatedP2(x: @[A1, B1, C1]), "080008010802")
    # echo "0a03000102" | xxd -r -p | protoc --decode=ObjRepeatedP2 test_std_enums_2.proto
    # packed
    let encoded = "0a03000102".hexToSeqByte
    check Protobuf.decode(encoded, ObjRepeatedP2) == ObjRepeatedP2(x: @[A1, B1, C1])

  test "proto2 repeated enum invalid":
    # echo "080008030802" | xxd -r -p | protoc --decode=ObjRepeatedP2 test_std_enums_2.proto
    # x: A1
    # x: C1
    # 1: 3
    let encoded = "080008030802".hexToSeqByte
    check Protobuf.decode(encoded, ObjRepeatedP2) == ObjRepeatedP2(x: @[A1, C1])

  test "proto2 repeated enum packed":
    # echo "0a03000102" | xxd -r -p | protoc --decode=ObjRepeatedPackedP2 test_std_enums_2.proto
    # echo 'x: 0 x: 1 x: 2' | protoc --encode=ObjRepeatedPackedP2 test_std_enums_2.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(ObjRepeatedPackedP2(x: @[A1, B1, C1]), "0a03000102")
    # echo "080008010802" | xxd -r -p | protoc --decode=ObjRepeatedP2 test_std_enums_2.proto
    # unpacked
    let encoded = "080008010802".hexToSeqByte
    check Protobuf.decode(encoded, ObjRepeatedPackedP2) == ObjRepeatedPackedP2(x: @[A1, B1, C1])

  test "proto2 repeated enum packed invalid":
    # echo "0a03000302" | xxd -r -p | protoc --decode=ObjRepeatedPackedP2 test_std_enums_2.proto
    # x: A1
    # x: C1
    # 1: 3
    let encoded = "0a03000302".hexToSeqByte
    check Protobuf.decode(encoded, ObjRepeatedPackedP2) == ObjRepeatedPackedP2(x: @[A1, C1])

  test "proto3 ordinal enum":
    # proto3 default (0 = A1) is not written to the wire
    roundtrip(ObjClassicP3(x: A1), "")
    roundtrip(ObjClassicP3(x: B1), "0801")
    roundtrip(ObjClassicP3(x: C1), "0802")

  test "proto3 unknown enum value is silently mapped to zero":
    # echo "0803" | xxd -r -p | protoc --decode=ObjClassicP3 test_std_enums_3.proto
    # x: 3
    # closed enum drops x: 3
    let encoded = "0803".hexToSeqByte
    check Protobuf.decode(encoded, ObjClassicP3) == ObjClassicP3(x: A1)

  test "proto3 enum with holes":
    # A2=-10, not 0 so it is encoded; B2=0 is the proto3 default so it is skipped
    roundtrip(ObjWithHolesP3(x: A2), "08f6ffffffffffffffff01")
    roundtrip(ObjWithHolesP3(x: C2), "080a")
    roundtrip(ObjWithHolesP3(x: D2), "080b")

  test "proto3 enum with int32 limits":
    # A3=int32.low, C3=int32.high; B3=0 is the proto3 default so it is skipped
    roundtrip(ObjLimitsP3(x: A3), "0880808080f8ffffffff01")
    roundtrip(ObjLimitsP3(x: C3), "08ffffffff07")
    roundtrip(ObjLimitsP3(x: B3), "")

  test "proto3 repeated enum":
    # echo "0a03000102" | xxd -r -p | protoc --decode=ObjRepeatedP3 test_std_enums_3.proto
    # echo 'x: 0 x: 1 x: 2' | protoc --encode=ObjRepeatedP3 test_std_enums_3.proto | hexdump -ve '1/1 "%.2x"'
    # roundtrip is packed for proto3
    roundtrip(ObjRepeatedP3(x: @[A1, B1, C1]), "0a03000102")
    # echo "0a03000102" | xxd -r -p | protoc --decode=ObjRepeatedP3 test_std_enums_3.proto
    # unpacked
    let encoded = "080008010802".hexToSeqByte
    check Protobuf.decode(encoded, ObjRepeatedP3) == ObjRepeatedP3(x: @[A1, B1, C1])

  test "proto3 repeated enum invalid":
    # echo "0a03000302" | xxd -r -p | protoc --decode=ObjRepeatedP3 test_std_enums_3.proto
    # x: A1
    # x: 3
    # x: C1
    # closed enum drops x: 3
    let encoded = "0a03000302".hexToSeqByte
    check Protobuf.decode(encoded, ObjRepeatedP3) == ObjRepeatedP3(x: @[A1, C1])

  test "proto3 repeated enum unpacked":
    # echo "080008010802" | xxd -r -p | protoc --decode=ObjRepeatedUnpackedP3 test_std_enums_3.proto
    # echo 'x: 0 x: 1 x: 2' | protoc --encode=ObjRepeatedUnpackedP3 test_std_enums_3.proto | hexdump -ve '1/1 "%.2x"'
    roundtrip(ObjRepeatedUnpackedP3(x: @[A1, B1, C1]), "080008010802")
    # echo "0a03000102" | xxd -r -p | protoc --decode=ObjRepeatedP3 test_std_enums_3.proto
    # packed
    let encoded = "0a03000102".hexToSeqByte
    check Protobuf.decode(encoded, ObjRepeatedUnpackedP3) == ObjRepeatedUnpackedP3(x: @[A1, B1, C1])

  test "proto3 repeated enum unpacked invalid":
    # echo "080008030802" | xxd -r -p | protoc --decode=ObjRepeatedUnpackedP3 test_std_enums_3.proto
    # x: A1
    # x: 3
    # x: C1
    # closed enum drops x: 3
    let encoded = "080008030802".hexToSeqByte
    check Protobuf.decode(encoded, ObjRepeatedUnpackedP3) == ObjRepeatedUnpackedP3(x: @[A1, C1])
