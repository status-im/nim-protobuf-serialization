import math
import unittest

import ../protobuf_serialization

func cstrlen(x: cstring): csize_t {.header: "string.h", importc: "strlen".}

suite "Test Length Delimited Encoding/Decoding":
  test "Can encode/decode string":
    let
      str = "Testing string.\0"
      output = Protobuf.encode(str)
    check output == @[byte(10), byte(str.len), 84, 101, 115, 116, 105, 110, 103, 32, 115, 116, 114, 105, 110, 103, 46, 0]
    check Protobuf.decode(output, type(string)) == str

  test "Can encode/decode char seq":
    let
      charSeq = cast[seq[char]]("Testing string.\0")
      output = Protobuf.encode(charSeq)
    check output == @[byte(10), byte(charSeq.len), 84, 101, 115, 116, 105, 110, 103, 32, 115, 116, 114, 105, 110, 103, 46, 0]
    check Protobuf.decode(output, type(seq[char])) == charSeq

  test "Can encode/decode uint8 seq":
    let
      uint8Seq = cast[seq[uint8]]("Testing string.\0")
      output = Protobuf.encode(uint8Seq)
    check output == @[byte(10), byte(uint8Seq.len), 84, 101, 115, 116, 105, 110, 103, 32, 115, 116, 114, 105, 110, 103, 46, 0]
    check Protobuf.decode(output, type(seq[uint8])) == uint8Seq

  test "Can encode/decode bool seq":
    let
      boolSeq = @[true, false, false, true, true, true, true, false, true, false, false, false]
      output = Protobuf.encode(boolSeq)
    check output == @[byte(10), byte(boolSeq.len), 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0]
    check Protobuf.decode(output, type(seq[bool])) == boolSeq

  test "Decoding a string/cstring doesn't remove the null terminator":
    let str = "Testing string."
    check cstrlen(Protobuf.decode(Protobuf.encode(str), string)) == csize_t(str.len)
    check cstrlen(Protobuf.decode(Protobuf.encode(str), cstring)) == csize_t(str.len)

    check cstrlen(Protobuf.decode(Protobuf.encode(cstring(str)), string)) == csize_t(str.len)
    check cstrlen(Protobuf.decode(Protobuf.encode(cstring(str)), cstring)) == csize_t(str.len)

  test "Can encode a string which has a length which requires three bytes to encode":
    let
      x = newString(2 ^ 15)
      vi = Protobuf.encode(PInt(x.len))
      encoded = Protobuf.encode(x)
    check encoded[1 ..< vi.len] == vi[1 ..< vi.len]
    check Protobuf.decode(encoded, string) == x
