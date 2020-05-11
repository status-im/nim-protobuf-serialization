import unittest

import ../protobuf_serialization

type
  PIntType = object
    x {.pint.}: int

  UIntType = object
    x {.puint.}: uint

  SIntType = object
    x {.sint.}: int

  BoolType = object
    x: bool

suite "Test Boolean Encoding/Decoding":
  test "Can encode/decode boolean as signed VarInt":
    assert not writeValue(PInt(0'i32)).readValue(bool)
    assert writeValue(PInt(1'i32)).readValue(bool)
    assert not writeValue(PInt(0'i64)).readValue(bool)
    assert writeValue(PInt(1'i64)).readValue(bool)

    assert not writeValue(PIntType(x: 0)).readValue(BoolType).x
    assert writeValue(PIntType(x: 1)).readValue(BoolType).x

  test "Can encode/decode boolean as unsigned VarInt":
    assert not writeValue(UInt(0'u32)).readValue(bool)
    assert writeValue(UInt(1'u32)).readValue(bool)
    assert not writeValue(UInt(0'u64)).readValue(bool)
    assert writeValue(UInt(1'u64)).readValue(bool)

    assert not writeValue(UIntType(x: 0'u)).readValue(BoolType).x
    assert writeValue(UIntType(x: 1'u)).readValue(BoolType).x

  test "Can encode/decode boolean as zigzagged VarInt":
    assert not writeValue(SInt(0'i32)).readValue(bool)
    assert writeValue(SInt(1'i32)).readValue(bool)
    assert not writeValue(SInt(0'i64)).readValue(bool)
    assert writeValue(SInt(1'i64)).readValue(bool)

    assert not writeValue(SIntType(x: 0)).readValue(BoolType).x
    assert writeValue(SIntType(x: 1)).readValue(BoolType).x
