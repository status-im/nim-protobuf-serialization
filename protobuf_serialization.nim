import faststreams

const
  MaxMessageSize* = 1'u shl 22

type
  ProtoBuffer* = ref object
    fieldNum: int
    outstream: OutputStreamVar

  ProtoWireType* = enum
    ## Protobuf's field types enum
    Varint, Fixed64, Length, StartGroup, EndGroup, Fixed32

  ProtoField* = object
    ## Protobuf's message field representation object
    index: int
    case kind: ProtoWireType
    of Varint:
      vint*: uint64
    of Fixed64:
      vfloat64*: float64
    of Length:
      vbuffer*: OutputStreamVar
    of Fixed32:
      vfloat32*: float32
    of StartGroup, EndGroup:
      discard

  SomeSVarint* = int | int64 | int32 | int16 | int8 | enum
  SomeUVarint* = uint | uint64 | uint32 | uint16 | uint8 | byte | bool
  SomeVarint* = SomeSVarint | SomeUVarint

proc newProtoBuffer*(): ProtoBuffer =
  ProtoBuffer(outstream: OutputStream.init(), fieldNum: 1)

# Main interface
proc encode*(): ProtoBuffer =
  discard

proc decode*[T](source: ProtoBuffer): T =
  discard

template wireType(firstByte: byte): ProtoWireType =
  (firstByte and 0b111).ProtoWireType

template fieldNumber(firstByte: byte): uint =
  (firstByte shr 3) and 0b1111

template protoHeader*(fieldNum: int, wire: ProtoWireType): byte =
  ## Get protobuf's field header integer for ``index`` and ``wire``.
  ((cast[uint](fieldNum) shl 3) or cast[uint](wire)).byte

proc encodeVarint(stream: OutputStreamVar, fieldNum: int, value: SomeVarint) {.inline.} =
  let header = protoHeader(fieldNum, Varint)
  stream.append header

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

proc encode(protobuf: ProtoBuffer, value: SomeVarint) {.inline.} =
  protobuf.outstream.encodeVarint(protobuf.fieldNum, value)
  inc protobuf.fieldNum

proc decode[T: SomeVarint](bytes: var seq[byte], ty: typedesc[T], offset = 0): tuple[fieldNum: uint, value: T] {.inline.} =
  # Only up to 128 bits supported by the spec
  assert (bytes.len - 1) <= 16

  let wireTy = wireType(bytes[offset])
  if wireTy != Varint:
    raise newException(Exception, "Not a varint!")

  result.fieldNum = fieldNumber(bytes[offset])
  result.value = cast[ty](0)
  var shiftAmount = 0
  var i = offset + 1
  while true:
    result.value += T(bytes[i] and 0b0111_1111) shl shiftAmount
    shiftAmount += 7
    if (bytes[i] shr 7) == 0:
      break
    i += 1

  when ty is SomeSVarint:
    if (result.value and T(1)) != T(0):
      result.value = cast[T](not(result.value shr T(1)))
    else:
      result.value = cast[T](result.value shr T(1))

proc main() =
  let proto = newProtoBuffer()
  proto.encode(-1500000)
  var input: seq[byte] = proto.outstream.getOutput
  echo input

  echo decode(input, int64)

main()