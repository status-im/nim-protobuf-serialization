import unittest2
import stew/byteutils
import ../protobuf_serialization

type
  Bytes {.proto3.} = object
    x {.fieldNumber: 1.}: seq[byte]

  Varint {.proto3.} = object
    x {.fieldNumber: 1, pint.}: int64

suite "Test well formed messages":
  test "Bytes len 0":
    # field 1, length-delimited, varint for 0
    # echo "0A00" | xxd -r -p | protoc --decode=Bytes test_malformed.proto
    let encoded = "0A00".hexToSeqByte
    check ProtoBuf.decode(encoded, Bytes) == Bytes()

  test "Bytes len 1":
    # echo "0a0161" | xxd -r -p | protoc --decode=Bytes test_malformed.proto
    # x: "a"
    let encoded = "0a0161".hexToSeqByte
    check ProtoBuf.decode(encoded, Bytes) == Bytes(x: @['a'.byte])

  test "Length of 32-bit":
    # echo "0A818080800061" | xxd -r -p | protoc --decode=Bytes test_malformed.proto
    # x: "a"
    let encoded = "0A818080800061".hexToSeqByte
    check ProtoBuf.decode(encoded, Bytes) == Bytes(x: @['a'.byte])

  test "Varint max int64":
    let encoded = "08FFFFFFFFFFFFFFFF7F".hexToSeqByte
    check ProtoBuf.decode(encoded, Varint) == Varint(x: int64.high)

suite "Test malformed messages":
  test "Max uint32 + 1 length":
    # echo "0A8080808010" | xxd -r -p | protoc --decode=Bytes test_malformed.proto
    # Failed to parse input.
    # this must be rejected, not truncated; truncated == 0 (valid)
    let encoded = "0A8080808010".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Max uint32 length":
    # echo "0AFFFFFFFF0F" | xxd -r -p | protoc --decode=Bytes test_malformed.proto
    # Failed to parse input.
    let encoded = "0AFFFFFFFF0F".hexToSeqByte
    # XXX should throw ProtobufLengthError; this could fail as "not enough bytes" to read
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Max uint64 length":
    let encoded = "0AFFFFFFFFFFFFFFFFFF01".hexToSeqByte
    # XXX should throw ProtobufVarintError; this could fail as "not enough bytes" to read
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Max int64 length":
    # field 1, length-delimited, varint for int64.high
    let encoded = "0AFFFFFFFFFFFFFFFF7F".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)
 
  test "Length greater than bytes data":
    let encoded = "0A054142".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Length 0 with trailing garbage":
    let encoded = "0A00FFFF".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Truncated varint length":
    let encoded = "0A8080808080".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Overlong varint encoding":
    let encoded = "0A81808080808080808000".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Length of 64-bit":
    # echo "0A8180808080808080800061" | xxd -r -p | protoc --decode=Bytes test_malformed.proto
    # Failed to parse input.
    let encoded = "0A8180808080808080800061".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Lenght of 64-bit variant":
    let encoded = "08010AFFFFFFFFFFFFFFFF7F1002".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Length varint overflow":
    # echo "0AFFFFFFFFFFFFFFFFFFFF01" | xxd -r -p | protoc --decode=Bytes test_malformed.proto
    # Failed to parse input.
    let encoded = "0AFFFFFFFFFFFFFFFFFFFF01".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Field key truncated":
    let encoded = "80".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Invalid wire type 7":
    let encoded = "0F".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Bytes)

  test "Varint greater than max uint64":
    let encoded = "08FFFFFFFFFFFFFFFFFFFF01".hexToSeqByte
    expect(ProtobufValueError):
      discard ProtoBuf.decode(encoded, Varint)
