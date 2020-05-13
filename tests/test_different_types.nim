import unittest

import ../protobuf_serialization

suite "Test Encoding X and decoding into Y":
  test "* into VarInt":
    expect ProtobufMessageError:
      discard Fixed(5'u32).writeValue().readValue(SInt(int32))
    expect ProtobufMessageError:
      discard Fixed(5'u64).writeValue().readValue(SInt(int32))

    expect ProtobufMessageError:
      discard "Test string.".writeValue().readValue(SInt(int32))

  test "* into Fixed":
    expect ProtobufMessageError:
      discard PInt(5'i32).writeValue().readValue(Fixed(uint32))

    expect ProtobufMessageError:
      discard "Test string.".writeValue().readValue(Fixed(uint32))

  test "* into LengthDelimited":
    expect ProtobufMessageError:
      discard PInt(5'i32).writeValue().readValue(string)

    expect ProtobufMessageError:
      discard Fixed(5'u32).writeValue().readValue(string)
    expect ProtobufMessageError:
      discard Fixed(5'u64).writeValue().readValue(string)
