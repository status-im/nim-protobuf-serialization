import unittest

import ../protobuf_serialization

type
  PIntType = object
    x {.pint.}: int32

  UIntType = object
    x {.puint.}: uint32

  SIntType = object
    x {.sint.}: int32

  BoolType = object
    x: bool

proc writeRead[W, R](toWrite: W, readAs: typedesc[R], value: R) =
  var res: readAs
  ProtobufReader.init(unsafeMemoryInput(writeValue(toWrite))).readValue(res)
  check res == value

suite "Test Boolean Encoding/Decoding":
  test "Can encode/decode boolean without subtype specification":
    writeRead(true, bool, true)
    writeRead(false, bool, false)

    writeRead(BoolType(x: true), BoolType, BoolType(x: true))
    writeRead(BoolType(x: false), BoolType, BoolType(x: false))

  #Skipping subtype specification only works when every encoding has the same truthiness.
  #That's what this tests. It should be noted 1 encodes as 1/1/2 for the following.
  test "Can encode/decode boolean as signed VarInt":
    writeRead(PInt(0'i32), bool, false)
    writeRead(PInt(0'i64), bool, false)
    writeRead(PInt(1'i32), bool, true)
    writeRead(PInt(1'i64), bool, true)

    writeRead(PIntType(x: 1), BoolType, BoolType(x: true))
    writeRead(PIntType(x: 0), BoolType, BoolType(x: false))

  test "Can encode/decode boolean as unsigned VarInt":
    writeRead(UInt(0'u32), bool, false)
    writeRead(UInt(0'u64), bool, false)
    writeRead(UInt(1'u32), bool, true)
    writeRead(UInt(1'u64), bool, true)

    writeRead(UIntType(x: 1), BoolType, BoolType(x: true))
    writeRead(UIntType(x: 0), BoolType, BoolType(x: false))

  test "Can encode/decode boolean as zig-zagged VarInt":
    writeRead(SInt(0'i32), bool, false)
    writeRead(SInt(0'i64), bool, false)
    writeRead(SInt(1'i32), bool, true)
    writeRead(SInt(1'i64), bool, true)

    writeRead(SIntType(x: 1), BoolType, BoolType(x: true))
    writeRead(SIntType(x: 0), BoolType, BoolType(x: false))
