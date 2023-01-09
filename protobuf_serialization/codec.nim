# Copyright (c) 2022 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

## This module implements core primitives for the protobuf language as seen in
## `.proto` files

# TODO fix exception raising - should probably only raise ProtoError derivatives
#      and whatever streams already raises
#
# when (NimMajor, NimMinor) < (1, 4):
#   {.push raises: [Defect].}
# else:
#   {.push raises: [].}

import
  std/[typetraits, unicode],
  faststreams,
  stew/[leb128, endians2]

type
  WireKind* = enum
    Varint = 0
    Fixed64 = 1
    LengthDelim = 2
    # StartGroup = 3 # Not used
    # EndGroup = 4 # Not used
    Fixed32 = 5

  FieldHeader* = distinct uint32

  # Scalar types used in `.proto` files
  # https://developers.google.com/protocol-buffers/docs/proto3#scalar
  pdouble* = distinct float64
  pfloat* = distinct float32

  pint32* = distinct int32 ## varint-encoded signed integer
  pint64* = distinct int64 ## varint-encoded signed integer

  puint32* = distinct uint32 ## varint-encoded unsigned integer
  puint64* = distinct uint64 ## varint-encoded unsigned integer

  sint32* = distinct int32 ## zig-zag-varint-encoded signed integer
  sint64* = distinct int64 ## zig-zag-varint-encoded signed integer

  fixed32* = distinct uint32 ## fixed-width unsigned integer
  fixed64* = distinct uint64 ## fixed-width unsigned integer

  sfixed32* = distinct int32 ## fixed-width signed integer
  sfixed64* = distinct int64 ## fixed-width signed integer

  pbool* = distinct bool

  pstring* = distinct string ## UTF-8-encoded string
  pbytes* = distinct seq[byte] ## byte sequence

  SomeScalar* =
    pint32 | pint64 | puint32 | puint64 | sint32 | sint64 | pbool |
    fixed64 | sfixed64 | pdouble |
    pstring | pbytes |
    fixed32 | sfixed32 | pfloat

  # Mappings of proto type to wire type
  SomeVarint* =
    pint32 | pint64 | puint32 | puint64 | sint32 | sint64 | pbool
  SomeFixed64* = fixed64 | sfixed64 | pdouble
  SomeLengthDelim* = pstring | pbytes # Also messages and packed repeated fields
  SomeFixed32* = fixed32 | sfixed32 | pfloat

  SomePrimitive* = SomeVarint | SomeFixed64 | SomeFixed32
    ## Types that may appear packed

const
  SupportedWireKinds* = {
    uint8(WireKind.Varint),
    uint8(WireKind.Fixed64),
    uint8(WireKind.LengthDelim),
    uint8(WireKind.Fixed32)
  }

template wireKind*(T: type SomeVarint): WireKind = WireKind.Varint
template wireKind*(T: type SomeFixed64): WireKind = WireKind.Fixed64
template wireKind*(T: type SomeLengthDelim): WireKind = WireKind.LengthDelim
template wireKind*(T: type SomeFixed32): WireKind = WireKind.Fixed32

template validFieldNumber*(i: int, strict: bool = false): bool =
  # https://developers.google.com/protocol-buffers/docs/proto#assigning
  # Field numbers in the 19k range are reserved for the protobuf implementation
  (i > 0 and i < (1 shl 29)) and (not strict or not(i >= 19000 and i <= 19999))

template init*(_: type FieldHeader, index: int, wire: WireKind): FieldHeader =
  ## Get protobuf's field header integer for ``index`` and ``wire``.
  FieldHeader((uint32(index) shl 3) or uint32(wire))

template number*(p: FieldHeader): int =
  int(uint32(p) shr 3)

template kind*(p: FieldHeader): WireKind =
  cast[WireKind](uint8(p) and 0x07'u8) # 3 lower bits

template toUleb(x: puint64): uint64 = uint64(x)
template toUleb(x: puint32): uint32 = uint32(x)

func toUleb(x: sint64): uint64 =
  let v = cast[uint64](x)
  (v shl 1) xor (0 - (v shr 63))

func toUleb(x: sint32): uint32 =
  let v = cast[uint32](x)
  (v shl 1) xor (0 - (v shr 31))

template toUleb(x: pint64): uint64 = cast[uint64](x)
template toUleb(x: pint32): uint32 = cast[uint32](x)
template toUleb(x: pbool): uint8 = cast[uint8](x)

template fromUleb(x: uint64, T: type puint64): T = puint64(x)
template fromUleb(x: uint64, T: type pbool): T = pbool(x != 0)

template fromUleb(x: uint64, T: type puint64): T = puint64(x)
template fromUleb(x: uint64, T: type puint32): T = puint32(x)

template fromUleb(x: uint64, T: type sint64): T =
  cast[T]((x shr 1) xor (0 - (x and 1)))
template fromUleb(x: uint64, T: type sint32): T =
  cast[T]((uint32(x) shr 1) xor (0 - (uint32(x) and 1)))

template fromUleb(x: uint64, T: type pint64): T = cast[T](x)
template fromUleb(x: uint64, T: type pint32): T = cast[T](x)

template toBytes*(x: SomeVarint): openArray[byte] =
  toBytes(toUleb(x), Leb128).toOpenArray()

template toBytes*(x: fixed32 | fixed64): openArray[byte] =
  type Base = distinctBase(typeof(x))
  toBytesLE(Base(x))

template toBytes*(x: sfixed32): openArray[byte] =
  toBytes(fixed32(x))
template toBytes*(x: sfixed64): openArray[byte] =
  toBytes(fixed64(x))

template toBytes*(x: pdouble): openArray[byte] =
  cast[array[8, byte]](x)
template toBytes*(x: pfloat): openArray[byte] =
  cast[array[4, byte]](x)

template toBytes*(header: FieldHeader): openArray[byte] =
  toBytes(uint32(header), Leb128).toOpenArray()

proc vsizeof*(x: SomeVarint): int =
  ## Returns number of bytes required to encode integer ``x`` as varint.
  Leb128.len(toUleb(x))

proc writeValue*(output: OutputStream, value: SomeVarint) =
  output.write(toBytes(value))

proc writeValue*(output: OutputStream, value: SomeFixed64) =
  output.write(toBytes(value))

proc writeValue*(output: OutputStream, value: pstring) =
  output.write(toBytes(puint64(string(value).len())))
  output.write(string(value).toOpenArrayByte(0, string(value).high()))

proc writeValue*(output: OutputStream, value: pbytes) =
  output.write(toBytes(puint64(seq[byte](value).len())))
  output.write(seq[byte](value))

proc writeValue*(output: OutputStream, value: SomeFixed32) =
  output.write(toBytes(value))

proc writeField*(output: OutputStream, field: int, value: SomeScalar) =
  output.write(toBytes(FieldHeader.init(field, wireKind(typeof(value)))))
  output.writeValue(value)

proc readValue*[T: SomeVarint](input: InputStream, _: type T): T =
  # TODO This is not entirely correct: we should truncate value if it doesn't
  #      fit, according to the docs:
  #      https://developers.google.com/protocol-buffers/docs/proto#updating
  var buf: Leb128Buf[uint64]
  while buf.len < buf.data.len and input.readable():
    let b = input.read()
    buf.data[buf.len] = b
    buf.len += 1
    if (b and 0x80'u8) == 0:
      break

  let (val, len) = uint64.fromBytes(buf)
  if buf.len == 0 or len != buf.len:
    raise (ref ValueError)(msg: "Cannot read varint from stream")

  fromUleb(val, T)

proc readValue*[T: SomeFixed32 | SomeFixed64](input: InputStream, _: type T): T =
  var tmp {.noinit.}: array[sizeof(T), byte]
  if not input.readInto(tmp):
    raise (ref ValueError)(msg: "Not enough bytes")
  when T is pdouble | pfloat:
    copyMem(addr result, addr tmp[0], sizeof(result))
  elif sizeof(T) == 8:
    cast[T](uint64.fromBytesLE(tmp)) # Cast so we don't run into signed trouble
  else:
    cast[T](uint32.fromBytesLE(tmp)) # Cast so we don't run into signed trouble

proc readLength*(input: InputStream): int =
  let lenu32 = input.readValue(puint32)
  if uint64(lenu32) > uint64(int.high()):
    raise (ref ValueError)(msg: "Invalid length")
  int(lenu32)

proc readValue*[T: SomeLengthDelim](input: InputStream, _: type T): T =
  let len = input.readLength()
  if len > 0:
    type Base = typetraits.distinctBase(T)
    let inputLen = input.len()
    if inputLen.isSome() and len > inputLen.get():
        raise (ref ValueError)(msg: "Missing bytes: " & $len)

    Base(result).setLen(len)
    template bytes(): openArray[byte] =
      when Base is seq[byte]:
        Base(result).toOpenArray(0, len - 1)
      else:
        Base(result).toOpenArrayByte(0, len - 1)
    if not input.readInto(bytes()):
      raise (ref ValueError)(msg: "Missing bytes: " & $len)

    when T is pstring:
      if validateUtf8(string(result)) != -1:
        raise (ref ValueError)(msg: "String not valid UTF-8")

proc readHeader*(input: InputStream): FieldHeader =
  let
    hdr = uint32(input.readValue(puint32))
    wire = uint8(hdr and 0x07)

  if wire notin SupportedWireKinds:
    raise (ref ValueError)(msg: "Invalid wire type")

  FieldHeader(hdr)
