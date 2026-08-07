# ANCHOR: all
import protobuf_serialization

# ANCHOR: unpacked
type
  Numbers {.proto3.} = object
    values {.fieldNumber: 1, sint, packed: false.}: seq[int32]
    names {.fieldNumber: 2, packed: false.}: seq[string]
    flags {.fieldNumber: 3, packed: false.}: seq[bool]
# ANCHOR_END: unpacked

# ANCHOR: packed
type
  PackedNumbers {.proto2.} = object
    values {.fieldNumber: 1, sint, packed: true.}: seq[int32]
    flags {.fieldNumber: 2, packed: true.}: seq[bool]
    scores {.fieldNumber: 3, fixed, packed: true.}: seq[int32]
    weights {.fieldNumber: 4, packed: true.}: seq[float32]
# ANCHOR_END: packed

# ANCHOR: usage_unpacked
let nums = Numbers(
  values: @[5'i32, -3, 300, -612],
  names: @["zero", "one", "two"],
  flags: @[true, false, true]
)

let encoded = Protobuf.encode(nums)
let decoded = Protobuf.decode(encoded, Numbers)
assert decoded == nums
# ANCHOR_END: usage_unpacked

# ANCHOR: usage_packed
let packed = PackedNumbers(
  values: @[5'i32, -3, 300],
  flags: @[true, false, true],
  scores: @[100'i32, 200, 300],
  weights: @[1.5'f32, 2.5, 3.5]
)

let encodedPacked = Protobuf.encode(packed)
let decodedPacked = Protobuf.decode(encodedPacked, PackedNumbers)
assert decodedPacked == packed
# ANCHOR_END: usage_packed

echo "Repeated and packed fields example passed!"
# ANCHOR_END: all
