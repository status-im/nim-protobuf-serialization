# ANCHOR: all
import protobuf_serialization
import protobuf_serialization/pkg/results

# ANCHOR: type
type
  Message {.proto3.} = object
    count {.fieldNumber: 1, ext.}: Opt[int32]
    text {.fieldNumber: 2, ext.}: Opt[string]
# ANCHOR_END: type

# ANCHOR: create_ok
let msg1 = Message(
  count: Opt.ok(42'i32),
  text: Opt.ok("hello")
)
# ANCHOR_END: create_ok

# ANCHOR: create_err
let msg2 = Message(
  count: Opt.err(int32),
  text: Opt.err(string)
)
# ANCHOR_END: create_err

# ANCHOR: check
if msg1.count.isSome():
  echo "Count is set to: ", msg1.count.get()
else:
  echo "Count is not set"
# ANCHOR_END: check

# ANCHOR: get
let count = msg1.count.get()  # Returns the int32 value
# ANCHOR_END: get

# ANCHOR: valueor
let count2 = msg2.count.valueOr(0'i32)  # Returns 0 if not set
# ANCHOR_END: valueor

echo "Optional fields Opt example passed!"
# ANCHOR_END: all
