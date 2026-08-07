# Optional Fields Example
# Demonstrates both Opt[T] for proto3 and PBOption for proto2

import protobuf_serialization
import protobuf_serialization/pkg/results

# ANCHOR: proto3_default_problem
# Problem: In proto3, you can't distinguish between "not set" and "set to default"
type
  MessageDefault {.proto3.} = object
    count {.fieldNumber: 1.}: int32  # Defaults to 0
    text {.fieldNumber: 2.}: string  # Defaults to ""
# ANCHOR_END: proto3_default_problem

# ANCHOR: proto3_opt_type
# Solution: Use Opt[T] to make fields explicitly optional
type
  MessageOpt {.proto3.} = object
    count {.fieldNumber: 1, ext.}: Opt[int32]
    text {.fieldNumber: 2, ext.}: Opt[string]
# ANCHOR_END: proto3_opt_type

# ANCHOR: proto3_opt_create
# Creating optional values with Opt.some() and Opt.none()
let msg1 = MessageOpt(
  count: Opt.some(42'i32),
  text: Opt.some("hello")
)

let msg2 = MessageOpt(
  count: Opt.none(int32),
  text: Opt.none(string)
)
# ANCHOR_END: proto3_opt_create

# ANCHOR: proto3_opt_check
# Checking if a value is present
if msg1.count.isSome():
  echo "Count is set to: ", msg1.count.get()
else:
  echo "Count is not set"
# ANCHOR_END: proto3_opt_check

# ANCHOR: proto3_opt_get
# Getting the value
let count = msg1.count.get()  # Returns the int32 value
echo "Count: ", count
# ANCHOR_END: proto3_opt_get

# ANCHOR: proto3_opt_valueor
# Providing a default value
let count2 = msg2.count.valueOr(0'i32)  # Returns 0 if not set
echo "Count2: ", count2
# ANCHOR_END: proto3_opt_valueor

# ANCHOR: proto2_pboption_type
# For proto2, use PBOption to make fields explicitly optional
type
  Settings {.proto2.} = object
    username {.fieldNumber: 1, required.}: string
    theme {.fieldNumber: 2.}: PBOption[default(string)]
    fontSize {.fieldNumber: 3, pint.}: PBOption[0'i32]
    notifications {.fieldNumber: 4.}: PBOption[false]
# ANCHOR_END: proto2_pboption_type

# ANCHOR: proto2_pboption_create
# Creating optional values with pbSome() and pbNone()
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
# ANCHOR_END: proto2_pboption_create

# ANCHOR: proto2_pboption_encode_decode
# Encoding and decoding
let encoded = Protobuf.encode(settings2)
let decoded = Protobuf.decode(encoded, Settings)

assert decoded.username == "bob"
assert decoded.theme.isSome
assert decoded.theme.get == "light"
assert decoded.fontSize.isNone
assert decoded.notifications.isNone
# ANCHOR_END: proto2_pboption_encode_decode

# ANCHOR: proto2_pboption_valueor
# Providing a default value
let fontSize = decoded.fontSize.valueOr(12'i32)
assert fontSize == 12
echo "Font size: ", fontSize
# ANCHOR_END: proto2_pboption_valueor

echo "Optional fields example passed!"
