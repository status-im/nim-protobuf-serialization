import sets
import unittest2

import ../protobuf_serialization

type
  Sequences {.protobuf3.} = object
    x {.sint, fieldNumber: 1.}: seq[int32]
    y {.fieldNumber: 2.}: seq[bool]
    z {.fieldNumber: 3.}: seq[string]

suite "Test repeated fields":
  test "Can encode/decode stdlib fields where a pragma was used to specify encoding":
    let pragmad = Sequences(
      x: @[5'i32, -3'i32, 300'i32, -612'i32],
      y: @[true, false, true, true, false, false, false, true, false],
      z: @["zero", "one", "two"]
    )
    check Protobuf.decode(Protobuf.encode(pragmad), Sequences) == pragmad
