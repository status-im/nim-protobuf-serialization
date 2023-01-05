import unittest2

import ../protobuf_serialization

type X {.proto3.} = object
  x00 {.fieldNumber: 1.}: bool
  x01 {.fieldNumber: 2.}: bool
  x02 {.fieldNumber: 3.}: bool
  x03 {.fieldNumber: 4.}: bool
  x04 {.fieldNumber: 5.}: bool
  x05 {.fieldNumber: 6.}: bool
  x06 {.fieldNumber: 7.}: bool
  x07 {.fieldNumber: 8.}: bool
  x08 {.fieldNumber: 9.}: bool
  x09 {.fieldNumber: 10.}: bool
  x0A {.fieldNumber: 11.}: bool
  x0B {.fieldNumber: 12.}: bool
  x0C {.fieldNumber: 13.}: bool
  x0D {.fieldNumber: 14.}: bool
  x0E {.fieldNumber: 15.}: bool
  x0F {.fieldNumber: 16.}: bool
  x10 {.fieldNumber: 17.}: bool
  x11 {.fieldNumber: 18.}: bool
  x12 {.fieldNumber: 19.}: bool
  x13 {.fieldNumber: 20.}: bool
  x14 {.fieldNumber: 21.}: bool
  x15 {.fieldNumber: 22.}: bool
  x16 {.fieldNumber: 23.}: bool
  x17 {.fieldNumber: 24.}: bool
  x18 {.fieldNumber: 25.}: bool
  x19 {.fieldNumber: 26.}: bool
  x1A {.fieldNumber: 27.}: bool
  x1B {.fieldNumber: 28.}: bool
  x1C {.fieldNumber: 29.}: bool
  x1D {.fieldNumber: 30.}: bool
  x1E {.fieldNumber: 31.}: bool
  x1F {.fieldNumber: 32.}: bool
  x20 {.fieldNumber: 33.}: bool

suite "Thirty-three fielded object":
  test "Can encode and decode an object with 33 fields":
    let x = X(
      x00: true,
      x01: true,
      x02: true,
      x03: true,
      x04: true,
      x05: true,
      x06: true,
      x07: true,
      x08: true,
      x09: true,
      x0A: true,
      x0B: true,
      x0C: true,
      x0D: true,
      x0E: true,
      x0F: true,
      x10: true,
      x11: true,
      x12: true,
      x13: true,
      x14: true,
      x15: true,
      x16: true,
      x17: true,
      x18: true,
      x19: true,
      x1A: true,
      x1B: true,
      x1C: true,
      x1D: true,
      x1E: true,
      x1F: true,
      x20: true
    )
    check Protobuf.decode(Protobuf.encode(x), X) == x
