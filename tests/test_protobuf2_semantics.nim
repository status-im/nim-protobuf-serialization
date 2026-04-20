# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2

import ../protobuf_serialization

type
  Required {.proto2.} = object
    a {.fieldNumber: 1, pint .}: PBOption[2'i32]
    b {.fieldNumber: 2, pint, required.}: int32

  FullOfDefaults {.proto2.} = object
    a {.fieldNumber: 3.}: PBOption["abc"]
    b {.fieldNumber: 4.}: PBOption[default(Required)]

  SeqContainer {.proto2.} = object
    data {.fieldNumber: 5.}: seq[bool]

  SeqString {.proto2.} = object
    data {.fieldNumber: 6.}: seq[string]

  FloatOption {.proto2.} = object
    x {.fieldNumber: 1.}: PBOption[0'f32]
    y {.fieldNumber: 2.}: PBOption[0'f64]

  FixedOption {.proto2.} = object
    a {.fieldNumber: 1, fixed.}: PBOption[0'i32]
    b {.fieldNumber: 2, fixed.}: PBOption[0'i64]
    c {.fieldNumber: 3, fixed.}: PBOption[0'u32]
    d {.fieldNumber: 4, fixed.}: PBOption[0'u64]

suite "Test Encoding of Protobuf 2 Semantics":
  test "PBOption basics":
    var opt: PBOption[true]
    check:
      pbSome(PBOption[true], false).isSome()
      pbSome(PBOption[true], false).get() == false
      opt.get() == true

    opt.init(false)
    check:
      opt.isSome() == true
      opt.get() == false

  test "Encodes required":
    check Protobuf.encode(Required(b: 0'i32)).len == 2

  test "Encodes set":
    check Protobuf.encode(Required(a: pbSome(type(Required.a), 0'i32), b: 0'i32)).len == 4

  test "Requires required":
    expect ProtobufReadError:
      discard Protobuf.decode(default(seq[byte]), Required)

  test "Handles default":
    var fod: FullOfDefaults = FullOfDefaults(b: PBOption[default(Required)].pbSome(Required(b: 5)))
    check:
      Protobuf.decode(Protobuf.encode(Required()), Required).a.isNone()
      Protobuf.decode(Protobuf.encode(Required()), Required).a.get() == 2

      Protobuf.decode(Protobuf.encode(fod), FullOfDefaults).a.isNone()
      Protobuf.decode(Protobuf.encode(fod), FullOfDefaults).a.get() == "abc"

      Protobuf.decode(Protobuf.encode(fod), FullOfDefaults).b.isSome()
      Protobuf.decode(Protobuf.encode(fod), FullOfDefaults).b.get().a.get() == 2'i32

  test "Doesn't require Option for seq":
    check Protobuf.decode(Protobuf.encode(SeqContainer()), SeqContainer).data.len == 0

  test "Can encode a seq[string] correctly":
    var ssb: SeqString = SeqString()
    check Protobuf.decode(Protobuf.encode(ssb), SeqString) == ssb
    ssb = SeqString(data: newSeq[string](0))
    check Protobuf.decode(Protobuf.encode(ssb), SeqString) == ssb
    ssb = SeqString(data: newSeq[string](1))
    check Protobuf.decode(Protobuf.encode(ssb), SeqString) == ssb
    ssb = SeqString(data: @["abc"])
    check Protobuf.decode(Protobuf.encode(ssb), SeqString) == ssb
    ssb = SeqString(data: @["abc", "def"])
    check Protobuf.decode(Protobuf.encode(ssb), SeqString) == ssb
    ssb = SeqString(data: @["abc", "def", ""])
    check Protobuf.decode(Protobuf.encode(ssb), SeqString) == ssb
    ssb = SeqString(data: @["abc", "def", "ghi"])
    check Protobuf.decode(Protobuf.encode(ssb), SeqString) == ssb

  test "Option[Float] in object":
    var x = FloatOption(x: PBOption[0'f32].pbSome(1.5'f32))
    check Protobuf.decode(Protobuf.encode(x), FloatOption) == x

    var y = FloatOption(y: PBOption[0'f64].pbSome(1.3'f64))
    check Protobuf.decode(Protobuf.encode(y), FloatOption) == y

    var z = FloatOption(
      x: PBOption[0'f32].pbSome(1.5'f32),
      y: PBOption[0'f64].pbSome(1.3'f64))
    check Protobuf.decode(Protobuf.encode(z), FloatOption) == z

    var v = FloatOption()
    check Protobuf.decode(Protobuf.encode(v), FloatOption) == v

  test "Option[Fixed] in object":
    var x = FixedOption(a: PBOption[0'i32].pbSome(1'i32))
    check Protobuf.decode(Protobuf.encode(x), FixedOption) == x

    var y = FixedOption(b: PBOption[0'i64].pbSome(1'i64))
    check Protobuf.decode(Protobuf.encode(y), FixedOption) == y

    var z = FixedOption(c: PBOption[0'u32].pbSome(1'u32))
    check Protobuf.decode(Protobuf.encode(z), FixedOption) == z

    var v = FixedOption(d: PBOption[0'u64].pbSome(1'u64))
    check Protobuf.decode(Protobuf.encode(v), FixedOption) == v

  test "pbSome ergonomic":
    check:
      PBOption[0'i64].pbSome(1'i64) == pbSome(1'i64)
      PBOption[0'i32].pbSome(1'i32) == pbSome(1'i32)
      PBOption[0'u64].pbSome(1'u64) == pbSome(1'u64)
      PBOption[0'u32].pbSome(1'u32) == pbSome(1'u32)
      PBOption[0'f64].pbSome(1'f64) == pbSome(1'f64)
      PBOption[0'f32].pbSome(1'f32) == pbSome(1'f32)
      PBOption[false].pbSome(true) == pbSome(true)
      PBOption[""].pbSome("abc") == pbSome("abc")
      PBOption[default(seq[byte])].pbSome(@[1'u8]) == pbSome(@[1'u8])
      PBOption[default(Required)].pbSome(Required()) == pbSome(Required())

  test "pbNone ergonomic":
    check:
      pbNone("").isNone
      PBOption[""]() == pbNone("")
      PBOption[default(Required)]() == pbNone(default(Required))

  test "PBOptional get with default":
    check:
      pbSome(1'i64).get(123'i64) == 1'i64
      pbNone(0'i64).get(123'i64) == 123'i64
      pbSome(1'i32).get(123'i32) == 1'i32
      pbNone(0'i32).get(123'i32) == 123'i32
      pbSome(1'u64).get(123'u64) == 1'u64
      pbNone(0'u64).get(123'u64) == 123'u64
      pbSome(1'u32).get(123'u32) == 1'u32
      pbNone(0'u32).get(123'u32) == 123'u32
      pbSome(1'f64).get(123'f64) == 1'f64
      pbNone(0'f64).get(123'f64) == 123'f64
      pbSome(1'f32).get(123'f32) == 1'f32
      pbNone(0'f32).get(123'f32) == 123'f32
      pbSome(true).get(false) == true
      pbSome(false).get(true) == false
      pbNone(false).get(true) == true
      pbNone(true).get(false) == false
      pbSome("abc").get("def") == "abc"
      pbNone("").get("def") == "def"
      pbSome(@[1'u8]).get(@[123'u8]) == @[1'u8]
      pbNone(default(seq[byte])).get(@[123'u8]) == @[123'u8]
      pbSome(Required(b: 1)).get(Required(b: 123)) == Required(b: 1)
      pbNone(default(Required)).get(Required(b: 123)) == Required(b: 123)
