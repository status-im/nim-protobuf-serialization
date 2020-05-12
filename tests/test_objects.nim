import unittest

import ../protobuf_serialization

type
  Nested = ref object
    child: Nested
    data: string

  Circular = ref object
    child: Circular

suite "Test Object Encoding/Decoding":
  test "Doesn't write too-big nested objects":
    expect ProtobufWriteError:
      discard writeValue(Nested(
        child: Nested(
          data: cast[string](newSeq[char](150))
        ),
        data: cast[string](newSeq[char](150))
      ))

  test "Doesn't write circular objects":
    let root = Circular()
    root.child = root
    expect ProtobufWriteError:
      discard writeValue(root)

  test "Doesn't fully recurse over nested objects which are too-big":
    #Created in a non-recursive format to not trigger the call depth.
    #We do use the Circular type yet we do NOT set the child back to self.
    var
      root = Circular()
      last = root
    #2000 is the call depth limit.
    #The extra 5 ensures we go over.
    for _ in 0 ..< 2005:
      last.child = Circular()
      last = last.child
    #This should raise without crashing.
    expect ProtobufWriteError:
      discard writeValue(root)

  test "Can read nested objects":
    discard
