import faststreams

import common
export PureTypes

const LAST_BYTE = 0b1111_1111

type
  FixedWrapped64  = distinct uint64
  FixedWrapped32  = distinct uint32
  SFixedWrapped64 = distinct int64
  SFixedWrapped32 = distinct int32

  FixedDistinctWrapped = FixedWrapped64 or FixedWrapped32 or
                         SFixedWrapped64 or SFixedWrapped32

  FixedWrapped* = FixedDistinctWrapped or float64 or float32

  WrappableFixedTypes = PureUIntegerTypes or PureSIntegerTypes

  #Every type valid for the Fixed (64 or 43) wire type.
  FixedTypes* = FixedWrapped or WrappableFixedTypes

generateWrapper(
  Fixed, WrappableFixedTypes, FixedDistinctWrapped,
  PureUIntegerTypes, FixedWrapped64, FixedWrapped32,
  PureSIntegerTypes, SFixedWrapped64, SFixedWrapped32,
  "Fixed should only be used with a non-float number. Floats are always fixed already."
)

template unwrap*(value: FixedWrapped): untyped =
  when value is FixedWrapped64:
    uint64(value)
  elif value is FixedWrapped32:
    uint32(value)
  elif value is SFixedWrapped64:
    int64(value)
  elif value is SFixedWrapped32:
    int32(value)
  elif value is (float64 or float32):
    value
  else:
    {.fatal: "Tried to get the unwrapped value of a non-wrapped type. This should never happen.".}

template fixed*() {.pragma.}

proc encodeFixed*(stream: OutputStream, value: FixedWrapped) =
  when sizeof(value) == 8:
    var casted = cast[uint64](value)
  else:
    var casted = cast[uint32](value)

  for _ in 0 ..< sizeof(casted):
    stream.write(byte(casted and LAST_BYTE))
    casted = casted shr 8

proc decodeFixed*(
  stream: InputStream,
  res: var auto
) =
  when sizeof(res) == 8:
    var temp: uint64
  else:
    var temp: uint32
  for i in 0 ..< sizeof(temp):
    temp = temp + (type(temp)(stream.read()) shl (i * 8))
  res = cast[type(res)](temp)
