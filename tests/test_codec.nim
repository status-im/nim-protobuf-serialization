# Nim-Libp2p
# Copyright (c) 2022 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  unittest2
import ../protobuf_serialization/codec
import stew/byteutils
import faststreams/[inputs, outputs]

when defined(nimHasUsed): {.used.}

suite "codec test suite":
  const VarintVectors = [
    "00", "01", "ffffffff07", "ffffffff0f", "ffffffffffffffff7f",
    "ffffffffffffffffff01"
  ]

  const VarintValues = [
    0x0'u64, 0x1'u64, 0x7FFF_FFFF'u64, 0xFFFF_FFFF'u64,
    0x7FFF_FFFF_FFFF_FFFF'u64, 0xFFFF_FFFF_FFFF_FFFF'u64
  ]

  const Fixed32Vectors = [
    "00000000", "01000000", "ffffff7f", "ddccbbaa", "ffffffff"
  ]

  const Fixed32Values = [
    0x0'u32, 0x1'u32, 0x7FFF_FFFF'u32, 0xAABB_CCDD'u32, 0xFFFF_FFFF'u32
  ]

  const Fixed64Vectors = [
    "0000000000000000", "0100000000000000", "ffffff7f00000000",
    "ddccbbaa00000000", "ffffffff00000000", "ffffffffffffff7f",
    "9988ffeeddccbbaa", "ffffffffffffffff"
  ]

  const Fixed64Values = [
    0x0'u64, 0x1'u64, 0x7FFF_FFFF'u64, 0xAABB_CCDD'u64, 0xFFFF_FFFF'u64,
    0x7FFF_FFFF_FFFF_FFFF'u64, 0xAABB_CCDD_EEFF_8899'u64,
    0xFFFF_FFFF_FFFF_FFFF'u64
  ]

  const LengthVectors = [
   "00", "0161", "026162", "0461626364", "086162636465666768"
  ]

  const LengthValues = [
    "", "a", "ab", "abcd", "abcdefgh"
  ]

  proc getVarintEncodedValue(value: uint64): seq[byte] =
    let
      output = memoryOutput()
    output.writeValue(puint64(value))
    output.getOutput()

  proc getVarintDecodedValue(data: openArray[byte]): uint64 =
    let
      input = memoryInput(data)
    input.readValue(puint64).uint64

  proc getFixed32EncodedValue(value: float32): seq[byte] =
    let
      output = memoryOutput()
    output.writeValue(pfloat(value))
    output.getOutput()

  proc getFixed32DecodedValue(data: openArray[byte]): uint32 =
    let
      input = memoryInput(data)
    input.readValue(fixed32).uint32

  proc getFixed64EncodedValue(value: float64): seq[byte] =
    let
      output = memoryOutput()
    output.writeValue(pdouble(value))
    output.getOutput()

  proc getFixed64DecodedValue(data: openArray[byte]): uint64 =
    let
      input = memoryInput(data)
    input.readValue(fixed64).uint64

  proc getLengthEncodedValue(value: string): seq[byte] =
    let
      output = memoryOutput()
    output.writeValue(pstring(value))
    output.getOutput()

  proc getLengthEncodedValue(value: seq[byte]): seq[byte] =
    let
      output = memoryOutput()
    output.writeValue(pbytes(value))
    output.getOutput()

  proc getLengthDecodedValue(data: openArray[byte]): string =
    let
      input = memoryInput(data)
    input.readValue(pstring).string

  test "[varint] edge values test":
    for i in 0 ..< len(VarintValues):
      let data = getVarintEncodedValue(VarintValues[i])
      check:
        toHex(data) == VarintVectors[i]
        data.len == computeSize(puint64(VarintValues[i]))

        getVarintDecodedValue(data) == VarintValues[i]

  test "[varint] incorrect values test":
    for i in 0 ..< len(VarintValues):
      var data = getVarintEncodedValue(VarintValues[i])
      # corrupting
      data.setLen(len(data) - 1)

      expect(ValueError):
        discard readValue(memoryInput(data), puint64)

  test "[fixed32] edge values test":
    for i in 0 ..< len(Fixed32Values):
      let data = getFixed32EncodedValue(cast[float32](Fixed32Values[i]))
      check:
        toHex(data) == Fixed32Vectors[i]
        data.len == computeSize(fixed32(Fixed32Values[i]))
        getFixed32DecodedValue(data) == Fixed32Values[i]

  test "[fixed32] incorrect values test":
    for i in 0 ..< len(Fixed32Values):
      var data = getFixed32EncodedValue(float32(Fixed32Values[i]))
      # corrupting
      data.setLen(len(data) - 1)
      expect(ValueError):
        discard readValue(memoryInput(data), fixed32)

  test "[fixed64] edge values test":
    for i in 0 ..< len(Fixed64Values):
      let data = getFixed64EncodedValue(cast[float64](Fixed64Values[i]))
      check:
        toHex(data) == Fixed64Vectors[i]
        data.len == computeSize(fixed64(Fixed64Values[i]))
        getFixed64DecodedValue(data) == Fixed64Values[i]

  test "[fixed64] incorrect values test":
    for i in 0 ..< len(Fixed64Values):
      var data = getFixed64EncodedValue(cast[float64](Fixed64Values[i]))
      # corrupting
      data.setLen(len(data) - 1)
      expect(ValueError):
        discard readValue(memoryInput(data), fixed64)

  test "[length] edge values test":
    for i in 0 ..< len(LengthValues):
      let data1 = getLengthEncodedValue(LengthValues[i])
      let data2 = getLengthEncodedValue(toBytes(LengthValues[i]))
      check:
        toHex(data1) == LengthVectors[i]
        computeSize(pstring(LengthValues[i])) == data1.len
        toHex(data2) == LengthVectors[i]
        computeSize(pbytes(toBytes(LengthValues[i]))) == data2.len
      check:
        getLengthDecodedValue(data1) == LengthValues[i]
        getLengthDecodedValue(data2) == LengthValues[i]

  test "[length] incorrect values test":
    for i in 0 ..< len(LengthValues):
      var data = getLengthEncodedValue(LengthValues[i])
      # corrupting
      data.setLen(len(data) - 1)

      expect(ValueError):
        discard readValue(memoryInput(data), pbytes)

  test "Truncation":
    # As reported using `echo "field: 18446744073709551614" | protoc uint.proto --encode | protoc test.proto --decode=Test`
    # and the various types
    let
      data = getVarintEncodedValue(uint64.high - 1)
    check:
      memoryInput(data).readValue(puint32).uint32 == 4294967294'u32
      memoryInput(data).readValue(pint64).int64 == -2
      memoryInput(data).readValue(pint32).int32 == -2
      memoryInput(data).readValue(sint64).int64 == 9223372036854775807
      memoryInput(data).readValue(sint32).int32 == 2147483647
      memoryInput(data).readValue(pbool).bool
