# ANCHOR: all
import protobuf_serialization

# ANCHOR: basic
type
  Person {.proto3.} = object
    name {.fieldNumber: 1.}: string
    age {.fieldNumber: 2, pint.}: int32
    email {.fieldNumber: 3.}: string
# ANCHOR_END: basic

# ANCHOR: pint
type
  Counter {.proto3.} = object
    count {.fieldNumber: 1, pint.}: int32
# ANCHOR_END: pint

# ANCHOR: sint
type
  Temperature {.proto3.} = object
    celsius {.fieldNumber: 1, sint.}: int32
# ANCHOR_END: sint

# ANCHOR: fixed
type
  LargeNumber {.proto3.} = object
    value {.fieldNumber: 1, fixed.}: uint64
# ANCHOR_END: fixed

# ANCHOR: nested
type
  Address {.proto3.} = object
    street {.fieldNumber: 1.}: string
    city {.fieldNumber: 2.}: string
    zipCode {.fieldNumber: 3.}: string

  PersonWithAddress {.proto3.} = object
    name {.fieldNumber: 1.}: string
    age {.fieldNumber: 2, pint.}: int32
    address {.fieldNumber: 3.}: Address
# ANCHOR_END: nested

let person = Person(name: "Bob", age: 25, email: "bob@example.com")
let encoded = Protobuf.encode(person)
let decoded = Protobuf.decode(encoded, Person)
assert decoded == person

echo "Annotating objects example passed!"
# ANCHOR_END: all
