# Enums Example
# Demonstrates how Nim enums map to protobuf enums, their closed-enum
# semantics, and how to preserve proto3-compatible behavior with int32.

# ANCHOR: imports
import protobuf_serialization
import protobuf_serialization/std/enums
# ANCHOR_END: imports

import stew/byteutils

# ANCHOR: basic
type
  Status = enum
    Unknown  # ord 0
    Active   # ord 1
    Banned   # ord 2

  Account {.proto3.} = object
    status {.fieldNumber: 1, ext.}: Status
# ANCHOR_END: basic

block:
  # ANCHOR: basic_roundtrip
  let account = Account(status: Active)
  let encoded = Protobuf.encode(account)
  let decoded = Protobuf.decode(encoded, Account)
  assert decoded == account
  # ANCHOR_END: basic_roundtrip

# ANCHOR: holes
# Enum ordinals do not have to be contiguous.
type
  Priority = enum
    Low = -10
    Normal = 0
    High = 10
    Critical  # ord 11

  Task {.proto3.} = object
    priority {.fieldNumber: 1, ext.}: Priority
# ANCHOR_END: holes

block:
  for p in [Low, Normal, High, Critical]:
    let task = Task(priority: p)
    assert Protobuf.decode(Protobuf.encode(task), Task) == task

# ANCHOR: proto3_unknown
# Nim enums are closed: a decoded value that is not part of the enum cannot
# be represented, so it is dropped and the field keeps its zero value.
# The bytes "0803" encode field 1 (tag 08) with the value 3, which is not a
# valid Status. Decoding maps it to the zero value (Unknown) and drops the 3.
block:
  let encoded = "0803".hexToSeqByte
  let decoded = Protobuf.decode(encoded, Account)
  assert decoded.status == Unknown
# ANCHOR_END: proto3_unknown

# ANCHOR: proto2_required
type
  RequiredAccount {.proto2.} = object
    status {.fieldNumber: 1, required, ext.}: Status
# ANCHOR_END: proto2_required

# ANCHOR: proto2_required_invalid
# In proto2 with a required enum, an unknown value is a decode error.
block:
  let encoded = "0803".hexToSeqByte
  var raised = false
  try:
    discard Protobuf.decode(encoded, RequiredAccount)
  except ProtobufReadError:
    raised = true
  assert raised
# ANCHOR_END: proto2_required_invalid

# ANCHOR: proto2_optional
type
  OptionalAccount {.proto2.} = object
    status {.fieldNumber: 1, ext.}: PBOption[default(Status)]
# ANCHOR_END: proto2_optional

block:
  # ANCHOR: proto2_optional_roundtrip
  let present = OptionalAccount(status: pbSome(Active))
  assert Protobuf.decode(Protobuf.encode(present), OptionalAccount) == present

  # The PBOption parameter is the field's default value, not its type, so
  # pbNone takes the default value too: default(Status), i.e. Unknown.
  let absent = OptionalAccount(status: pbNone(default(Status)))
  assert Protobuf.decode(Protobuf.encode(absent), OptionalAccount) == absent
  # ANCHOR_END: proto2_optional_roundtrip

# ANCHOR: repeated
type
  # proto2 repeated fields are unpacked by default.
  StatusLogP2 {.proto2.} = object
    statuses {.fieldNumber: 1, ext.}: seq[Status]

  # proto3 repeated numeric/enum fields are packed by default.
  StatusLogP3 {.proto3.} = object
    statuses {.fieldNumber: 1, ext.}: seq[Status]

  # The packed pragma overrides the default in either syntax.
  StatusLogPacked {.proto2.} = object
    statuses {.fieldNumber: 1, ext, packed: true.}: seq[Status]
# ANCHOR_END: repeated

block:
  let log = StatusLogP3(statuses: @[Unknown, Active, Banned])
  assert Protobuf.decode(Protobuf.encode(log), StatusLogP3) == log

  # ANCHOR: repeated_invalid
  # Unknown entries in a repeated enum field are dropped; valid ones are kept.
  # "080008030802" is three unpacked entries: 0, 3 (invalid), 2.
  let encoded = "080008030802".hexToSeqByte
  let decoded = Protobuf.decode(encoded, StatusLogP2)
  assert decoded.statuses == @[Unknown, Banned]
  # ANCHOR_END: repeated_invalid

# ANCHOR: int_rewrite
# To get proto3-conformant, open-enum behavior, store the value as an int32
# instead of a Nim enum. Named values become constants, and any unknown value
# is preserved on decode instead of being dropped.
const
  StatusUnknown = 0'i32
  StatusActive = 1'i32
  StatusBanned = 2'i32

type
  OpenAccount {.proto3.} = object
    status {.fieldNumber: 1, pint.}: int32
# ANCHOR_END: int_rewrite

block:
  # ANCHOR: int_rewrite_preserved
  # The same "0803" bytes now round-trip: the unknown value 3 is preserved.
  let encoded = "0803".hexToSeqByte
  let decoded = Protobuf.decode(encoded, OpenAccount)
  assert decoded.status == 3'i32
  assert Protobuf.encode(decoded) == encoded
  # ANCHOR_END: int_rewrite_preserved

echo "Enums example passed!"
