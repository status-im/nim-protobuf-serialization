# Proto Editions Example
# Demonstrates the {.proto.} pragma, per-field presence (implicit, required,
# PBExplicit), and the edition parameter.

# ANCHOR: imports
import protobuf_serialization
# ANCHOR_END: imports

# ANCHOR: mixed
# With {.proto.}, presence is chosen per field:
#   - PBExplicit: explicit presence (like proto2 optional)
#   - required:   must be present in the encoded message
#   - implicit:   no presence tracking (like proto3 scalars)
type
  Mixed {.proto.} = object
    a {.fieldNumber: 1, pint.}: PBExplicit[0'i32]
    b {.fieldNumber: 2, pint, required.}: int32
    c {.fieldNumber: 3, pint, implicit.}: int32
# ANCHOR_END: mixed

block:
  # ANCHOR: mixed_roundtrip
  let msg = Mixed(a: pbSome(1'i32), b: 7'i32, c: 3'i32)
  let encoded = Protobuf.encode(msg)
  let decoded = Protobuf.decode(encoded, Mixed)
  assert decoded == msg
  # ANCHOR_END: mixed_roundtrip

# ANCHOR: implicit_default
# {.proto, implicit.} makes fields implicit by default, so they no longer
# need a per-field presence pragma (except required).
type
  Settings {.proto, implicit.} = object
    host {.fieldNumber: 1.}: string
    port {.fieldNumber: 2, pint.}: int32
    token {.fieldNumber: 3, pint.}: PBExplicit[0'i32]
# ANCHOR_END: implicit_default

block:
  let msg = Settings(host: "localhost", port: 8080'i32, token: pbSome(42'i32))
  assert Protobuf.decode(Protobuf.encode(msg), Settings) == msg

# ANCHOR: edition_year
# The edition year selects the protobuf edition the type conforms to. It must
# be one of the supported editions (2023, 2024, 2026); bare {.proto.} defaults
# to 2023. The year is validated at compile time but does not currently change
# the wire format, so these three types serialize identically.
type
  Config2023 {.proto: 2023, implicit.} = object
    value {.fieldNumber: 1, pint.}: int32

  Config2024 {.proto: 2024, implicit.} = object
    value {.fieldNumber: 1, pint.}: int32

  Config2026 {.proto: 2026, implicit.} = object
    value {.fieldNumber: 1, pint.}: int32
# ANCHOR_END: edition_year

block:
  # ANCHOR: edition_identical
  # All three editions produce the same bytes.
  let a = Protobuf.encode(Config2023(value: 5'i32))
  let b = Protobuf.encode(Config2024(value: 5'i32))
  let c = Protobuf.encode(Config2026(value: 5'i32))
  assert a == b
  assert b == c
  # ANCHOR_END: edition_identical

# ANCHOR: required_missing
# A required field that is absent from the encoded message is a decode error.
block:
  var raised = false
  try:
    discard Protobuf.decode(default(seq[byte]), Mixed)
  except ProtobufReadError:
    raised = true
  assert raised
# ANCHOR_END: required_missing

echo "Proto editions example passed!"
