# ANCHOR: all
# ANCHOR: import
import protobuf_serialization
# ANCHOR_END: import

# ANCHOR: type
type
  Person {.proto3.} = object
    name {.fieldNumber: 1.}: string
    age {.fieldNumber: 2, pint.}: int32
    email {.fieldNumber: 3.}: string
# ANCHOR_END: type

# ANCHOR: usage
let person = Person(
  name: "Alice",
  age: 30,
  email: "alice@example.com"
)

# Encode to bytes
let encoded = Protobuf.encode(person)

# Decode back to object
let decoded = Protobuf.decode(encoded, Person)

assert decoded == person
# ANCHOR_END: usage
echo "Basic quickstart example passed!"
# ANCHOR_END: all
