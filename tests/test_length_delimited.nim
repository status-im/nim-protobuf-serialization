import unittest

import ../protobuf_serialization

type
  TwoStrings = object
    a: string
    b: string

  TwoStringsWrapped = object
    strings: TwoStrings

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

  test "Can detect too-long lenth delimited buffer":
    let tooLong = newSeq[byte](256)
    expect ProtobufWriteError:
      discard Protobuf.encode(tooLong)

  #Bottom two tests are because of https://github.com/kayabaNerve/nim-protobuf-serialization/issues/13.
  test "Can handle buffers which almost exceed the length":
    discard Protobuf.encode(TwoStringsWrapped(strings: TwoStrings(
      #Field key + buffer length + 253 bytes hits the maximum buffer size exactly.
      #If this assigns any length to b, which should be omitted, this will fail.
      a: newString(253)
    )))

  test "Can handle buffers which just exceed the length":
    expect ProtobufWriteError:
      discard Protobuf.encode(TwoStringsWrapped(strings: TwoStrings(
        #Field key + buffer length + 251 bytes set 253 bytes used.
        a: newString(251),
        #Another field key + buffer length + 1 byte makes it 256.
        b: newString(1)
      )))
