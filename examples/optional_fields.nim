# ANCHOR: all
import protobuf_serialization

# ANCHOR: type
type
  Settings {.proto2.} = object
    username {.fieldNumber: 1, required.}: string
    theme {.fieldNumber: 2.}: PBOption[default(string)]
    fontSize {.fieldNumber: 3, pint.}: PBOption[0'i32]
    notifications {.fieldNumber: 4.}: PBOption[false]
# ANCHOR_END: type

# ANCHOR: usage
let settings1 = Settings(
  username: "alice",
  theme: pbSome("dark"),
  fontSize: pbSome(14'i32),
  notifications: pbSome(true)
)

let settings2 = Settings(
  username: "bob",
  theme: pbSome("light"),
  fontSize: pbNone(0'i32),
  notifications: pbNone(false)
)

let encoded = Protobuf.encode(settings2)
let decoded = Protobuf.decode(encoded, Settings)

assert decoded.username == "bob"
assert decoded.theme.isSome
assert decoded.theme.get == "light"
assert decoded.fontSize.isNone
assert decoded.notifications.isNone

let fontSize = decoded.fontSize.valueOr(12'i32)
assert fontSize == 12
# ANCHOR_END: usage

echo "Optional fields example passed!"
# ANCHOR_END: all
