import sets
import unittest

import ../protobuf_serialization
from ../protobuf_serialization/internal import unwrap

suite "Test Standard Lib Objects Encoding/Decoding":
  test "Can encode/decode cstrings":
    let str: cstring = "Testing string."
    check str.writeValue().readValue(cstring) == str

  test "Can encode/decode seqs":
    let
      int64Seq = @[SInt(0'i64), SInt(-1'i64), SInt(1'i64), SInt(-1'i64)]
      read = int64Seq.writeValue().readValue(seq[SInt(int64)])
    check int64Seq.len == read.len
    for i in 0 ..< int64Seq.len:
      check int64Seq[i].unwrap() == read[i].unwrap()

  test "Can encode/decode arrays":
    let
      int64Arr = [SInt(0'i64), SInt(-1'i64), SInt(1'i64), SInt(-1'i64)]
      read = int64Arr.writeValue().readValue(seq[SInt(int64)])
    check int64Arr.len == read.len
    for i in 0 ..< int64Arr.len:
      check int64Arr[i].unwrap() == read[i].unwrap()

  test "Can encode/decode sets":
    let
      trueSet = {true}
      falseSet = {true}
      trueFalseSet = {true}
    check trueSet.writeValue().readValue(set[bool]) == trueSet
    check falseSet.writeValue().readValue(set[bool]) == falseSet
    check trueFalseSet.writeValue().readValue(set[bool]) == trueFalseSet

  test "Can encode/decode HashSets":
    let setInstance = ["abc", "def", "ghi"].toHashSet()
    check setInstance.writeValue().readValue(HashSet[string]) == setInstance
