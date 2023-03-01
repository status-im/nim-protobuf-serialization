import unittest2

import
  ../protobuf_serialization,
  ../protobuf_serialization/codec

type
#  TestEnum = enum
#    A1 = 0
#    B1 = 1000
#    C1 = 1000000

  Basic {.proto3.} = object
    a {.fieldNumber: 1, pint.}: uint64
    b {.fieldNumber: 2.}: string
    # TODO char is not a basic protobuf type c {.fieldNumber: 3.}: char

  Wrapped {.proto3.} = object
    d {.fieldNumber: 1, sint.}: int32
    e {.fieldNumber: 2, sint.}: int64
    f {.fieldNumber: 3.}: Basic
    g {.fieldNumber: 4.}: string
    h {.fieldNumber: 5.}: bool
    #i {.fieldNumber: 6.}: TestEnum

discard Protobuf.supports(Basic)
discard Protobuf.supports(Wrapped)

suite "Test Object Encoding/Decoding":
  test "Can encode/decode objects":

    let
      obj = Basic(a: 100, b: "Test string.") # TODO, c: 'C')
      encoded = Protobuf.encode(obj)
    check Protobuf.decode(encoded, Basic) == obj

  test "Can encode/decode a wrapper object":
    let obj = Wrapped(
      d: 300,
      e: 200,
      f: Basic(a: 100, b: "Test string."), # TODO, c: 'C'),
      g: "Other test string.",
      h: true
    )
    check Protobuf.decode(Protobuf.encode(obj), type(Wrapped)) == obj

  test "Can encode/decode partial object":
    let
      obj = Wrapped(
        d: 300,
        e: 200,
        f: Basic(a: 100, b: "Test string."), # c: 'C'),
        g: "Other test string.",
        h: true
      )
      writer = memoryOutput()

    writer.writeField(1, sint32(obj.d))
    writer.writeField(3, obj.f, pbytes)
    writer.writeField(4, pstring(obj.g))

    let result = Protobuf.decode(writer.getOutput(), type(Wrapped))
    check result.d == obj.d
    check result.f == obj.f
    check result.g == obj.g
    check result.e == 0
    check result.h == false

  test "Can encode/decode out of order object":
    let
      obj = Wrapped(
        d: 300,
        e: 200,
        f: Basic(a: 100, b: "Test string."), # c: 'C'),
        g: "Other test string.",
        h: true
      )
      writer = memoryOutput()

    writer.writeField(3, obj.f, pbytes)
    #writer.writeField(6, penum(obj.i))
    writer.writeField(1, sint64(obj.d))
    writer.writeField(2, sint64(obj.e))
    writer.writeField(5, pbool(obj.h))
    writer.writeField(4, pstring(obj.g))

    check Protobuf.decode(writer.getOutput(), type(Wrapped)) == obj

  test "Can read repeated fields":
    let
      writer = memoryOutput()
      basic: Basic = Basic(b: "Initial string.")
      repeated = "Repeated string."

    writer.writeField(2, pstring(basic.b))
    writer.writeField(2, pstring(repeated))

    check Protobuf.decode(writer.getOutput(), type(Basic)) == Basic(b: repeated)
