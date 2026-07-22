# ANCHOR: all
import protobuf_serialization

# ANCHOR: type
type
  ContactKind {.pure.} = enum
    notSet
    email
    phone
    address

  ContactInfo {.proto3, oneof.} = object
    case kind: ContactKind
    of ContactKind.notSet:
      discard
    of ContactKind.email:
      email {.fieldNumber: 1.}: string
    of ContactKind.phone:
      phone {.fieldNumber: 2.}: string
    of ContactKind.address:
      address {.fieldNumber: 3.}: string

  Person {.proto3.} = object
    name {.fieldNumber: 10.}: string
    contact {.oneof.}: ContactInfo
# ANCHOR_END: type

# ANCHOR: usage
# Create a person with email contact
let person1 = Person(
  name: "Alice",
  contact: ContactInfo(kind: ContactKind.email, email: "alice@example.com")
)

assert person1.contact.kind == ContactKind.email
assert person1.contact.email == "alice@example.com"

# Encode and decode
let encoded = Protobuf.encode(person1)
let decoded = Protobuf.decode(encoded, Person)

assert decoded.name == "Alice"
assert decoded.contact.kind == ContactKind.email
assert decoded.contact.email == "alice@example.com"

# Create a person with phone contact
let person2 = Person(
  name: "Bob",
  contact: ContactInfo(kind: ContactKind.phone, phone: "+1234567890")
)

assert person2.contact.kind == ContactKind.phone
assert person2.contact.phone == "+1234567890"
# ANCHOR_END: usage

echo "Oneof example passed!"
# ANCHOR_END: all
