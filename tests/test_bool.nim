import unittest2

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

suite "Test Boolean Encoding/Decoding":
  test "Can encode/decode boolean without subtype specification":
    writeRead(BoolType(x: true), BoolType(x: true))
    writeRead(BoolType(x: false), BoolType(x: false))

  #Skipping subtype specification only works when every encoding has the same truthiness.
  #That's what this tests. It should be noted 1 encodes as 1/1/2 for the following.
  test "Can encode/decode boolean as signed VarInt":
    writeRead(PIntType(x: 1), BoolType(x: true))
    writeRead(PIntType(x: 0), BoolType(x: false))

  test "Can encode/decode boolean as unsigned VarInt":
    writeRead(UIntType(x: 1), BoolType(x: true))
    writeRead(UIntType(x: 0), BoolType(x: false))

  test "Can encode/decode boolean as zig-zagged VarInt":
    # TODO 1 encodes as 2 in zig-zah - should we truncate? see `readVarint`
    writeRead(SIntType(x: 1), BoolType(x: true))
    writeRead(SIntType(x: 0), BoolType(x: false))
