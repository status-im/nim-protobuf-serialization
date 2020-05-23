import sets
import unittest

import ../protobuf_serialization
from ../protobuf_serialization/internal import unwrap

type
  Basic = object
    x {.pint.}: int32
    y: seq[string]

  PragmadStdlib = object
    x {.sint.}: seq[int32]
    y {.puint.}: array[5, uint32]
    z {.fixed.}: HashSet[float32]

  BooldStdlib = object
    x: seq[bool]
    y: array[3, bool]

suite "Test Standard Lib Objects Encoding/Decoding":
  test "Can encode/decode cstrings":
    let str: cstring = "Testing string."
    check Protobuf.decode(Protobuf.encode(str), type(cstring)) == str

  test "Can encode/decode seqs":
    let
      int64Seq = @[SInt(0'i64), SInt(-1'i64), SInt(1'i64), SInt(-1'i64)]
      read = Protobuf.decode(Protobuf.encode(int64Seq), seq[SInt(int64)])
    check int64Seq.len == read.len
    for i in 0 ..< int64Seq.len:
      check int64Seq[i].unwrap() == read[i].unwrap()

    let basicSeq = @[
      Basic(
        x: 0,
        y: @[]
      ),
      Basic(
        x: 1,
        y: @["abc", "defg"]
      ),
      Basic(
        x: 2,
        y: @["hi", "jkl", "mnopq"]
      ),
      Basic(
        x: -2,
        y: @["xyz"]
      )
    ]
    check basicSeq == Protobuf.decode(Protobuf.encode(basicSeq), seq[Basic])

  test "Can encode/decode arrays":
    let
      int64Arr = [SInt(0'i64), SInt(-1'i64), SInt(1'i64), SInt(-1'i64)]
      read = Protobuf.decode(Protobuf.encode(int64Arr), type(seq[SInt(int64)]))
    check int64Arr.len == read.len
    for i in 0 ..< int64Arr.len:
      check int64Arr[i].unwrap() == read[i].unwrap()

  test "Can encode/decode sets":
    let
      trueSet = {true}
      falseSet = {true}
      trueFalseSet = {true}
    check Protobuf.decode(Protobuf.encode(trueSet), type(set[bool])) == trueSet
    check Protobuf.decode(Protobuf.encode(falseSet), type(set[bool])) == falseSet
    check Protobuf.decode(Protobuf.encode(trueFalseSet), type(set[bool])) == trueFalseSet

  test "Can encode/decode HashSets":
    let setInstance = ["abc", "def", "ghi"].toHashSet()
    check Protobuf.decode(Protobuf.encode(setInstance), type(HashSet[string])) == setInstance


  test "Can encode/decode stdlib fields where a pragma was used to specify encoding":
    let pragmad = PragmadStdLib(
      x: @[5'i32, -3'i32, 300'i32, -612'i32],
      y: [6'u32, 4'u32, 301'u32, 613'u32, 216'u32],
      z: @[5.5'f32, 3.2'f32, 925.123].toHashSet()
    )
    check Protobuf.decode(Protobuf.encode(pragmad), PragmadStdLib) == pragmad

  test "Can encode boolean seqs/arrays":
    let boold = BooldStdlib(
      x: @[true, false, true, true, false, false, false, true, false],
      y: [true, true, false]
    )
    check Protobuf.decode(Protobuf.encode(boold), BooldStdlib) == boold
