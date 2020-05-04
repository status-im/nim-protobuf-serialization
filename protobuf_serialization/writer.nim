import faststreams
import types

type
  ProtoBuffer* = object
    fieldNum: int
    outstream: OutputStreamVar

proc newProtoBuffer*(): ProtoBuffer =
  ProtoBuffer(outstream: OutputStream.init(), fieldNum: 1)

proc output*(proto: ProtoBuffer): seq[byte] {.inline.} =
  proto.outstream.getOutput
template protoHeader*(fieldNum: int, wire: ProtoWireType): byte =
  ## Get protobuf's field header integer for ``index`` and ``wire``.
  ((cast[uint](fieldNum) shl 3) or cast[uint](wire)).byte

proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, value: T) {.inline.}
proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, fieldNum: int, value: T) {.inline.}
proc encodeField[T: not AnyProtoType](stream: OutputStreamVar, fieldNum: int, value: T) {.inline.}

proc put(stream: OutputStreamVar, value: SomeVarint) {.inline.} =
  when value is enum:
    var value = cast[type(ord(value))](value)
  elif value is bool or value is char:
    var value = cast[byte](value)
  else:
    var value = value

  when type(value) is SomeSVarint:
    # Encode using zigzag
    if value < type(value)(0):
      value = not(value shl type(value)(1))
    else:
      value = value shl type(value)(1)

  while value > type(value)(0b0111_1111):
    stream.append byte((value and 0b0111_1111) or 0b1000_0000)
    value = value shr 7
  stream.append byte(value and 0b1111_1111)

proc encodeField(stream: OutputStreamVar, fieldNum: int, value: SomeVarint) {.inline.} =
  stream.append protoHeader(fieldNum, Varint)
  stream.put(value)

proc put(stream: OutputStreamVar, value: SomeFixed) {.inline.} =
  when typeof(value) is SomeFixed64:
    var value = cast[int64](value)
  else:
    var value = cast[int32](value)

  for _ in 0 ..< sizeof(value):
    stream.append byte(value and 0b1111_1111)
    value = value shr 8

proc encodeField(stream: OutputStreamVar, fieldNum: int, value: SomeFixed64) {.inline.} =
  stream.append protoHeader(fieldNum, Fixed64)
  stream.put(value)

proc encodeField(stream: OutputStreamVar, fieldNum: int, value: SomeFixed32) {.inline.} =
  stream.append protoHeader(fieldNum, Fixed32)
  stream.put(value)

proc put(stream: OutputStreamVar, value: SomeLengthDelimited) {.inline.} =
  stream.put(len(value).uint)
  for b in value:
    stream.append byte(b)

proc encodeField(stream: OutputStreamVar, fieldNum: int, value: SomeLengthDelimited) {.inline.} =
  stream.append protoHeader(fieldNum, LengthDelimited)
  stream.put(value)

proc put(stream: OutputStreamVar, value: object) {.inline.}

proc encodeField(stream: OutputStreamVar, fieldNum: int, value: object) {.inline.} =
  # This is currently needed in order to get the size
  # of the output before adding it to the stream.
  # Maybe there is a better way to do this
  let objStream = OutputStream.init()
  objStream.put(value)

  let objOutput = objStream.getOutput()
  if objOutput.len > 0:
    stream.append protoHeader(fieldNum, LengthDelimited)
    stream.put(objOutput)

proc put(stream: OutputStreamVar, value: object) {.inline.} =
  var fieldNum = 1
  for _, val in value.fieldPairs:
    # Only store the value
    if default(type(val)) != val:
      stream.encodeField(fieldNum, val)
    inc fieldNum

proc encode*(protobuf: var ProtoBuffer, value: object) {.inline.} =
  protobuf.outstream.put(value)

proc encodeField*(protobuf: var ProtoBuffer, fieldNum: int, value: AnyProtoType) {.inline.} =
  protobuf.outstream.encodeField(fieldNum, value)

proc encodeField*(protobuf: var ProtoBuffer, value: AnyProtoType) {.inline.} =
  protobuf.encodeField(protobuf.fieldNum, value)
  inc protobuf.fieldNum

proc encodeField[T: not AnyProtoType](stream: OutputStreamVar, fieldNum: int, value: T) {.inline.} =
  stream.encodeField(fieldNum, value.toBytes)

proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, fieldNum: int, value: T) {.inline.} =
  protobuf.outstream.encodeField(fieldNum, value.toBytes)

proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, value: T) {.inline.} =
  protobuf.encodeField(protobuf.fieldNum, value.toBytes)
  inc protobuf.fieldNum
