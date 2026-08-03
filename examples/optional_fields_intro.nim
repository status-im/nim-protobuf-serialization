# ANCHOR: default_values
type
  Message {.proto3.} = object
    count {.fieldNumber: 1.}: int32  # Defaults to 0
    text {.fieldNumber: 2.}: string  # Defaults to ""
# ANCHOR_END: default_values

# ANCHOR: opt_type
import protobuf_serialization
import protobuf_serialization/pkg/results

type
  Message {.proto3.} = object
    count {.fieldNumber: 1.}: Opt[int32]
    text {.fieldNumber: 2.}: Opt[string]
# ANCHOR_END: opt_type

# ANCHOR: opt_some
let msg = Message(
  count: Opt.some(42'i32),
  text: Opt.some("hello")
)
# ANCHOR_END: opt_some

# ANCHOR: opt_none
let msg2 = Message(
  count: Opt.none(int32),
  text: Opt.none(string)
)
# ANCHOR_END: opt_none

# ANCHOR: opt_check
if msg.count.isSome:
  echo "Count is set to: ", msg.count.get
else:
  echo "Count is not set"
# ANCHOR_END: opt_check

# ANCHOR: opt_get
let count = msg.count.get  # Returns the int32 value
# ANCHOR_END: opt_get

# ANCHOR: opt_valueor
let count2 = msg2.count.valueOr(0'i32)  # Returns 0 if not set
# ANCHOR_END: opt_valueor
