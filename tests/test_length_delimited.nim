import unittest

import ../protobuf_serialization

suite "Test Length Delimited Encoding/Decoding":
  test "Can encode/decode string":
    let
      str = "Testing string.\0"
      output = writeValue(str)
    check output == @[byte(10), byte(str.len), 84, 101, 115, 116, 105, 110, 103, 32, 115, 116, 114, 105, 110, 103, 46, 0]
    check readValue(output, string) == str

  test "Can encode/decode char seq":
    let
      charSeq = cast[seq[char]]("Testing string.\0")
      output = writeValue(charSeq)
    check output == @[byte(10), byte(charSeq.len), 84, 101, 115, 116, 105, 110, 103, 32, 115, 116, 114, 105, 110, 103, 46, 0]
    check readValue(output, seq[char]) == charSeq

  test "Can encode/decode uint8 seq":
    let
      uint8Seq = cast[seq[uint8]]("Testing string.\0")
      output = writeValue(uint8Seq)
    check output == @[byte(10), byte(uint8Seq.len), 84, 101, 115, 116, 105, 110, 103, 32, 115, 116, 114, 105, 110, 103, 46, 0]
    check readValue(output, seq[uint8]) == uint8Seq

  test "Can encode/decode bool seq":
    let
      boolSeq = @[true, false, false, true, true, true, true, false, true, false, false, false]
      output = writeValue(boolSeq)
    check output == @[byte(10), byte(boolSeq.len), 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0]
    check readValue(output, seq[bool]) == boolSeq

  test "Can detect too-long lenth delimited buffer":
    let tooLong = newSeq[byte](256)
    expect ProtobufWriteError:
      discard writeValue(tooLong)
