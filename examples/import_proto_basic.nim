# ANCHOR: all
import protobuf_serialization
import protobuf_serialization/proto_parser

# This macro generates Person and AddressBook types at compile time
import_proto3 "person.proto3"

# Now you can use the generated types as if they were manually defined
let person = Person(
  name: "Alice",
  age: 30,
  email: "alice@example.com"
)

let encoded = Protobuf.encode(person)
let decoded = Protobuf.decode(encoded, Person)

assert decoded.name == "Alice"
assert decoded.age == 30
assert decoded.email == "alice@example.com"

echo "Import proto basic example passed!"
# ANCHOR_END: all
