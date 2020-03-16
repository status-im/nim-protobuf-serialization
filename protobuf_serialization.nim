import macros, strformat
import faststreams

const
  MaxMessageSize* = 1'u shl 22

type
  ProtoBuffer* = ref object
    fieldNum: int
    outstream: OutputStreamVar

  ProtoWireType* = enum
    ## Protobuf's field types enum
    Varint, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  ProtoField* = object
    ## Protobuf's message field representation object
    index: int
    case kind: ProtoWireType
    of Varint:
      vint*: uint64
    of Fixed64:
      vfloat64*: float64
    of LengthDelimited:
      vbuffer*: OutputStreamVar
    of Fixed32:
      vfloat32*: float32
    of StartGroup, EndGroup:
      discard

  SomeSVarint* = int | int64 | int32 | int16 | int8 | enum
  SomeUVarint* = uint | uint64 | uint32 | uint16 | uint8 | byte | bool
  SomeVarint* = SomeSVarint | SomeUVarint
  SomeLengthDelimited* = string | seq[byte] | seq[uint8] | cstring

proc newProtoBuffer*(): ProtoBuffer =
  ProtoBuffer(outstream: OutputStream.init(), fieldNum: 1)

# Main interface
proc encode*(): ProtoBuffer =
  discard

proc decode*[T](source: ProtoBuffer): T =
  discard

proc output*(proto: ProtoBuffer): seq[byte] {.inline.} =
  proto.outstream.getOutput

template wireType(firstByte: byte): ProtoWireType =
  (firstByte and 0b111).ProtoWireType

template fieldNumber(firstByte: byte): uint =
  (firstByte shr 3) and 0b1111

template protoHeader*(fieldNum: int, wire: ProtoWireType): byte =
  ## Get protobuf's field header integer for ``index`` and ``wire``.
  ((cast[uint](fieldNum) shl 3) or cast[uint](wire)).byte

proc putVarint(stream: OutputStreamVar, value: SomeVarint) {.inline.} =
  when value is enum:
    var value = cast[type(ord(value))](value)
  elif value is bool:
    var value = cast[byte](value)
  else:
    var value = value

  when type(value) is SomeSVarint:
    if value < type(value)(0):
      value = not(value shl type(value)(1))
    else:
      value = value shl type(value)(1)

  while value > type(value)(0b0111_1111):
    stream.append byte((value and 0b0111_1111) or 0b1000_0000)
    value = value shr 7
  stream.append byte(value and 0b1111_1111)

proc encode(stream: OutputStreamVar, fieldNum: int, value: SomeVarint) {.inline.} =
  stream.append protoHeader(fieldNum, Varint)
  stream.putVarint(value)

proc encode*(protobuf: ProtoBuffer, value: SomeVarint) {.inline.} =
  protobuf.outstream.encode(protobuf.fieldNum, value)
  inc protobuf.fieldNum

proc putLengthDelimited(stream: OutputStreamVar, value: SomeLengthDelimited) {.inline.} =
  for b in value:
    stream.append byte(b)

proc encode(stream: OutputStreamVar, fieldNum: int, value: SomeLengthDelimited) {.inline.} =
  stream.append protoHeader(fieldNum, LengthDelimited)
  stream.putVarint(len(value).uint)
  stream.putLengthDelimited(value)

proc encode*(protobuf: ProtoBuffer, value: SomeLengthDelimited) {.inline.} =
  protobuf.outstream.encode(protobuf.fieldNum, value)
  inc protobuf.fieldNum

proc getVarint[T: SomeVarint](bytes: var seq[byte], ty: typedesc[T], offset = 0): tuple[value: T, bytesProcessed: int] {.inline.} =
  # Only up to 128 bits supported by the spec
  when T is enum:
    var value: type(ord(result.value))
  else:
    var value: T
  var shiftAmount = 0
  var i = offset
  while true:
    value += type(value)(bytes[i] and 0b0111_1111) shl shiftAmount
    shiftAmount += 7
    if (bytes[i] shr 7) == 0:
      break
    i += 1

  result.bytesProcessed = i

  when ty is SomeSVarint:
    if (value and type(value)(1)) != type(value)(0):
      result.value = cast[T](not(value shr type(value)(1)))
    else:
      result.value = cast[T](value shr type(value)(1))
  else:
    result.value = value

proc decode*[T: SomeVarint](bytes: var seq[byte], ty: typedesc[T], offset = 0): tuple[fieldNum: uint, value: T, bytesProcessed: int] {.inline.} =
  # Only up to 128 bits supported by the spec
  assert (bytes.len - 1) <= 16

  let wireTy = wireType(bytes[offset])
  if wireTy != Varint:
    raise newException(Exception, fmt"Not a varint at offset {offset}! Received a {wireTy}")

  result.fieldNum = fieldNumber(bytes[offset])
  var offset = offset + 1

  let varGet = getVarint(bytes, ty, offset)
  result.value = varGet.value
  result.bytesProcessed = varGet.bytesProcessed + offset

proc getLengthDelimited*[T: SomeLengthDelimited](
  bytes: var seq[byte],
  ty: typedesc[T], offset = 0
): tuple[value: T, bytesProcessed: int] {.inline.} =

  var offset = offset
  let decodedSize = getVarint(bytes, uint, offset = offset)
  offset += decodedSize.bytesProcessed
  let length = decodedSize.value.int

  when T is string:
    result.value = newString(length)
    for i in offset ..< (offset + length):
      result.value[i - offset] = bytes[i].chr
  elif T is cstring:
    result.value = cast[cstring](bytes[offset ..< (offset + length)])
  else:
    result.value = newSeq(length)
    for i in offset ..< (offset + length):
      result.value[i - offset] = bytes[i].chr

  result.bytesProcessed += length

proc decode*[T: SomeLengthDelimited](
  bytes: var seq[byte],
  ty: typedesc[T], offset = 0
): tuple[fieldNum: uint, value: T, bytesProcessed: int] {.inline.} =
  var offset = offset

  let wireTy = wireType(bytes[offset])
  if wireTy != LengthDelimited:
    raise newException(Exception, fmt"Not a length delimited value at offset {offset}! Received a {wireTy}")

  result.fieldNum = fieldNumber(bytes[offset])

  offset += 1

  let lengthDelimited = getLengthDelimited(bytes, ty, offset)
  result.bytesProcessed = offset + lengthDelimited.bytesProcessed
  result.value = lengthDelimited.value