import unittest2

import ../protobuf_serialization

type
  PIntType {.proto3.} = object
    x {.fieldNumber: 1, pint.}: int32

  UIntType {.proto3.} = object
    x {.fieldNumber: 1, pint.}: uint32

  SIntType {.proto3.} = object
    x {.fieldNumber: 1, sint.}: int32

  BoolType {.proto3.} = object
    x {.fieldNumber: 1.}: bool

proc writeRead[W, R](toWrite: W, value: R) =
  let encoded = Protobuf.encode(toWrite)
  check:
    encoded.len == Protobuf.computeSize(toWrite)
    Protobuf.decode(encoded, R) == value

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
