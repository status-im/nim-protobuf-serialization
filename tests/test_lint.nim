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
