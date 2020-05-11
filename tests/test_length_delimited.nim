import unittest

import ../protobuf_serialization

type
  RecursiveX = ref object
    child: RecursiveX
    data: string

  RecursiveY = ref object
    child: RecursiveY
    data: seq[uint8]

  RecursiveZ = ref object
    child: RecursiveZ
    data {.fixed.}: int32

suite "Test Length Delimited Encoding/Decoding":
  #This should be modified.
  #We really need to test we can do this WITHOUT hitting the recursion limit.
  test "Can detect too-long length delimited buffers":
    expect ProtobufWriteError:
      discard writeValue(RecursiveX(
        child: RecursiveX(
          data: cast[string](newSeq[char](150))
        ),
        data: cast[string](newSeq[char](150))
      ))

    expect ProtobufWriteError:
      discard writeValue(RecursiveY(
        child: RecursiveY(
          data: newSeq[uint8](150)
        ),
        data: newSeq[uint8](150)
      ))

    #Created in a non-recursive format as if writing it triggers recursion, so will generating it.
    var
      root = RecursiveZ()
      last = root
    for _ in 0 ..< 100:
      last.data = 1
      last.child = RecursiveZ()
      last = last.child
    expect ProtobufWriteError:
      discard writeValue(root)

