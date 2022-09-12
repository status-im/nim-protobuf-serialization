import unittest

import ../protobuf_serialization

type
  PIntType {.protobuf3.} = object
    x {.pint, fieldNumber: 1.}: int32

  UIntType {.protobuf3.} = object
    x {.pint, fieldNumber: 1.}: uint32

  SIntType {.protobuf3.} = object
    x {.sint, fieldNumber: 1.}: int32

  BoolType {.protobuf3.} = object
    x {.fieldNumber: 1.}: bool

proc writeRead[W, R](toWrite: W, value: R) =
  check Protobuf.decode(Protobuf.encode(toWrite), R) == value

# TODO can't encode scalars, rewrite tests

suite "Test Boolean Encoding/Decoding":
  test "Can encode/decode boolean without subtype specification":
    # writeRead(true, true)
    # writeRead(false, false)

    writeRead(BoolType(x: true), BoolType(x: true))
    writeRead(BoolType(x: false), BoolType(x: false))

  #Skipping subtype specification only works when every encoding has the same truthiness.
  #That's what this tests. It should be noted 1 encodes as 1/1/2 for the following.
  test "Can encode/decode boolean as signed VarInt":
    # writeRead(PInt(0'i32), false)
    # writeRead(PInt(0'i64), false)
    # writeRead(PInt(1'i32), true)
    # writeRead(PInt(1'i64), true)

    writeRead(PIntType(x: 1), BoolType(x: true))
    writeRead(PIntType(x: 0), BoolType(x: false))

  test "Can encode/decode boolean as unsigned VarInt":
    # writeRead(PInt(0'u32), false)
    # writeRead(PInt(0'u64), false)
    # writeRead(PInt(1'u32), true)
    # writeRead(PInt(1'u64), true)

    writeRead(UIntType(x: 1), BoolType(x: true))
    writeRead(UIntType(x: 0), BoolType(x: false))

  # TODO these tests are wrong: zigzag encodes 1 as 2 which is not valid boolean
  # test "Can encode/decode boolean as zig-zagged VarInt":
  #   writeRead(SInt(0'i32), false)
  #   writeRead(SInt(0'i64), false)
  #   writeRead(SInt(1'i32), true)
  #   writeRead(SInt(1'i64), true)

  #   writeRead(SIntType(x: 1), BoolType(x: true))
  #   writeRead(SIntType(x: 0), BoolType(x: false))
