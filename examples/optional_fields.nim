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

# ANCHOR: create_some
let settings1 = Settings(
  username: "alice",
  theme: pbSome("dark"),
  fontSize: pbSome(14'i32),
  notifications: pbSome(true)
)

# ANCHOR_END: create_some

# ANCHOR: create_none
let settings2 = Settings(
  username: "bob",
  theme: pbSome("light"),
  fontSize: pbNone(0'i32),
  notifications: pbNone(false)
)

# ANCHOR_END: create_none

# ANCHOR: encode_decode
let encoded = Protobuf.encode(settings2)
let decoded = Protobuf.decode(encoded, Settings)

assert decoded.username == "bob"
assert decoded.theme.isSome
assert decoded.theme.get == "light"
assert decoded.fontSize.isNone
assert decoded.notifications.isNone

# ANCHOR: valueor
let fontSize = decoded.fontSize.valueOr(12'i32)
assert fontSize == 12
# ANCHOR_END: valueor

# ANCHOR: check
assert decoded.theme.isSome
assert decoded.theme.get == "light"
assert decoded.fontSize.isNone
assert decoded.notifications.isNone
# ANCHOR_END: check
# ANCHOR_END: usage

echo "Optional fields example passed!"
# ANCHOR_END: all
