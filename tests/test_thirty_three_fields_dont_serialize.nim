import ../protobuf_serialization

type X = object
  x00: bool
  x01: bool
  x02: bool
  x03: bool
  x04: bool
  x05: bool
  x06: bool
  x07: bool
  x08: bool
  x09: bool
  x0A: bool
  x0B: bool
  x0C: bool
  x0D: bool
  x0E: bool
  x0F: bool
  x10: bool
  x11: bool
  x12: bool
  x13: bool
  x14: bool
  x15: bool
  x16: bool
  x17: bool
  x18: bool
  x19: bool
  x1A: bool
  x1B: bool
  x1C: bool
  x1D: bool
  x1E: bool
  x1F: bool
  x20 {.dontSerialize.}: bool

discard writeValue(X())
