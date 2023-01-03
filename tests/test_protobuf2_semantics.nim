import unittest2

import ../protobuf_serialization

type
  Required {.protobuf2.} = object
    a {.pint, fieldNumber: 1.}: PBOption[2'i32]
    b {.pint, required, fieldNumber: 2.}: int32

  FullOfDefaults {.protobuf2.} = object
    a {.fieldNumber: 3.}: PBOption["abc"]
    b {.fieldNumber: 4.}: PBOption[default(Required)]

  SeqContainer {.protobuf2.} = object
    data {.fieldNumber: 5.}: seq[bool]

  SeqString {.protobuf2.} = object
    data {.fieldNumber: 6.}: seq[string]

  FloatOption {.protobuf2.} = object
    x {.fieldNumber: 1.}: PBOption[0'f32]
    y {.fieldNumber: 2.}: PBOption[0'f64]

  FixedOption {.protobuf2.} = object
    a {.fixed, fieldNumber: 1.}: PBOption[0'i32]
    b {.fixed, fieldNumber: 2.}: PBOption[0'i64]
    c {.fixed, fieldNumber: 3.}: PBOption[0'u32]
    d {.fixed, fieldNumber: 4.}: PBOption[0'u64]

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
      discard Protobuf.decode(@[], Required)

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
