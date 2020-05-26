import unittest

import ../protobuf_serialization
from ../protobuf_serialization/internal import unwrap

proc writeRead(x: auto) =
  let encoded = Protobuf.encode(LInt(x))
  #LInt sets a cap of 10 bytes. That said, the wire byte is prefixed.
  #Hence the 11.
  check encoded.len < 11
  check Protobuf.decode(encoded, type(LInt(x))).unwrap() == x

suite "Test LInt Encoding/Decoding":
  test "Can encode/decode uint":
    writeRead(0'u32)
    writeRead(1'u32)
    writeRead(254'u32)
    writeRead(255'u32)
    writeRead(256'u32)
    writeRead(1'u64 shl 62)

  test "Can detect too large uints":
    expect ProtobufWriteError:
      writeRead(1'u64 shl 63)

  #Following tests also work for VarInts in general.
  #We don't have a dedicated VarInt suite.
  test "Can detect overflown byte buffers":
    var
      bytes = @[byte(255), 255, 255, 255, 127]
      inLen: int
      res32: LInt(uint32)
      res64: LInt(uint32)
    check decodeVarInt(bytes, inLen, res32) == VarIntStatus.Overflow
    bytes = @[byte(255), 255, 255, 255, 255, 255, 255, 255, 255, 127]

    check decodeVarInt(bytes, inLen, res64) == VarIntStatus.Overflow

  test "Can handle the highest value for each encoding":
    check Protobuf.decode(Protobuf.encode(PInt(high(int32))), PInt(int32)).unwrap() == high(int32)
    check Protobuf.decode(Protobuf.encode(SInt(high(int32))), SInt(int32)).unwrap() == high(int32)
    check Protobuf.decode(Protobuf.encode(LInt(high(uint32))), LInt(uint32)).unwrap() == high(uint32)

    check Protobuf.decode(Protobuf.encode(PInt(high(int64))), PInt(int64)).unwrap() == high(int64)
    check Protobuf.decode(Protobuf.encode(SInt(high(int64))), SInt(int64)).unwrap() == high(int64)
    check Protobuf.decode(Protobuf.encode(LInt(high(uint64) shr 1)), LInt(uint64)).unwrap() == (high(uint64) shr 1)
    
