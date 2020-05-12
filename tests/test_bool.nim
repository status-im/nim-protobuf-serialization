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
  test "Can encode/decode boolean without subtype specification":
    check writeValue(true).readValue(bool)
    check not writeValue(false).readValue(bool)

    check writeValue(BoolType(x: true)).readValue(BoolType).x
    check not writeValue(BoolType(x: false)).readValue(BoolType).x

  #Skipping subtype specification only works when every encoding has the same truthiness.
  #That's what this tests. It should be noted 1 encodes as 1/1/2 for the following.
  test "Can encode/decode boolean as signed VarInt":
    check not writeValue(PInt(0'i32)).readValue(bool)
    check writeValue(PInt(1'i32)).readValue(bool)
    check not writeValue(PInt(0'i64)).readValue(bool)
    check writeValue(PInt(1'i64)).readValue(bool)

    check not writeValue(PIntType(x: 0)).readValue(BoolType).x
    check writeValue(PIntType(x: 1)).readValue(BoolType).x

  test "Can encode/decode boolean as unsigned VarInt":
    check not writeValue(UInt(0'u32)).readValue(bool)
    check writeValue(UInt(1'u32)).readValue(bool)
    check not writeValue(UInt(0'u64)).readValue(bool)
    check writeValue(UInt(1'u64)).readValue(bool)

    check not writeValue(UIntType(x: 0'u)).readValue(BoolType).x
    check writeValue(UIntType(x: 1'u)).readValue(BoolType).x

  test "Can encode/decode boolean as zig-zagged VarInt":
    check not writeValue(SInt(0'i32)).readValue(bool)
    check writeValue(SInt(1'i32)).readValue(bool)
    check not writeValue(SInt(0'i64)).readValue(bool)
    check writeValue(SInt(1'i64)).readValue(bool)

    check not writeValue(SIntType(x: 0)).readValue(BoolType).x
    check writeValue(SIntType(x: 1)).readValue(BoolType).x
