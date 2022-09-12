import unittest

import ../protobuf_serialization

proc writeRead[W, R](toWrite: W, readAs: typedesc[R]) =
  expect ProtobufMessageError:
    discard Protobuf.decode(Protobuf.encode(toWrite), R)

# suite "Test Encoding X and decoding into Y":
#   test "* into VarInt":
#     #Test the Fixed32 and Fixed64 wire types.
#     writeRead(Fixed(5'u32), SInt(int32))
#     writeRead(Fixed(5'u64), SInt(int32))

#     #LengthDelimited.
#     writeRead("Test string.", SInt(int32))

#   test "* into Fixed":
#     #VarInt.
#     writeRead(SInt(5'i32), Fixed(uint32))

#     #LengthDelimited.
#     writeRead("Test string.", Fixed(uint32))

#   test "* into LengthDelimited":
#     #VarInt.
#     writeRead(SInt(5'i32), string)

#     #Fixed.
#     writeRead(Fixed(5'u32), string)
#     writeRead(Fixed(5'u64), string)
