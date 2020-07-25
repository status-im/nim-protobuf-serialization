import options
import unittest

import ../protobuf_serialization

type
  Required {.protobuf2.} = object
    a {.pint, fieldNumber: 1.}: PBOption[2'i32]
    b {.pint, required, fieldNumber: 2.}: int32

  FullOfDefaults {.protobuf2.} = object
    a {.fieldNumber: 1.}: PBOption["abc"]
    b {.fieldNumber: 2.}: Option[Required]

  SeqContainer {.protobuf2.} = object
    data {.fieldNumber: 1.}: seq[bool]

  SeqString {.protobuf2.} = object
    data {.fieldNumber: 1.}: seq[string]

suite "Test Encoding of Protobuf 2 Semantics":
  test "Encodes required":
    check Protobuf.encode(Required(b: 0'i32)).len == 2

  test "Encodes set":
    check Protobuf.encode(Required(a: pbSome(type(Required.a), 0'i32), b: 0'i32)).len == 4

  test "Requires required":
    expect ProtobufReadError:
      discard Protobuf.decode(@[], Required)
    expect ProtobufReadError:
      discard Protobuf.decode(Protobuf.encode(PInt(0'i32)), Required)

  test "Handles default":
    var fod: FullOfDefaults = FullOfDefaults(b: some(Required(b: 5)))
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
