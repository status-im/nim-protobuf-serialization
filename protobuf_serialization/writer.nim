import faststreams/output_stream
import serialization
import types

type ProtoBuffer* = object
  fieldNum: int
  outstream: OutputStreamHandle

proc newProtoBuffer*(): ProtoBuffer {.inline.} =
  ProtoBuffer(outstream: memoryOutput(), fieldNum: 1)

proc output*(proto: ProtoBuffer): seq[byte] {.inline.} =
  proto.outstream.getOutput

template protoHeader*(fieldNum: int, wire: ProtoWireType): byte =
  ## Get protobuf's field header integer for ``index`` and ``wire``.
  ((cast[uint](fieldNum) shl 3) or cast[uint](wire)).byte

proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, value: T) {.inline.}
proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, fieldNum: int, value: T) {.inline.}
proc encodeField[T: not AnyProtoType](stream: OutputStreamHandle, fieldNum: int, value: T) {.inline.}

proc put(stream: OutputStreamHandle, value: VarIntTypes) =
  when value is enum:
    var value = cast[type(ord(value))](value)
  elif value is bool or value is char:
    var value = cast[byte](value)
  else:
    var value = value

  when type(value) is PureSIntegerTypes:
    # Encode using zigzag
    if value < type(value)(0):
      value = not(value shl type(value)(1))
    else:
      value = value shl type(value)(1)

  while value > type(value)(0b0111_1111):
    stream.s.cursor.append byte((value and 0b0111_1111) or 0b1000_0000)
    value = value shr 7
  stream.s.cursor.append byte(value and 0b1111_1111)

proc encodeField(stream: OutputStreamHandle, fieldNum: int, value: VarIntTypes) =
  stream.s.cursor.append protoHeader(fieldNum, Varint)
  stream.put(value)

proc put(stream: OutputStreamHandle, value: SomeFloat) =
  when typeof(value) is float64:
    var value = cast[int64](value)
  else:
    var value = cast[int32](value)

  for _ in 0 ..< sizeof(value):
    stream.s.cursor.append byte(value and 0b1111_1111)
    value = value shr 8

proc encodeField(stream: OutputStreamHandle, fieldNum: int, value: float64) =
  stream.s.cursor.append protoHeader(fieldNum, Fixed64)
  stream.put(value)

proc encodeField(stream: OutputStreamHandle, fieldNum: int, value: float32) =
  stream.s.cursor.append protoHeader(fieldNum, Fixed32)
  stream.put(value)

proc put(stream: OutputStreamHandle, value: SomeLengthDelimited) =
  stream.put(len(value).uint)
  for b in value:
    stream.s.cursor.append byte(b)

proc encodeField(stream: OutputStreamHandle, fieldNum: int, value: SomeLengthDelimited) =
  stream.s.cursor.append protoHeader(fieldNum, LengthDelimited)
  stream.put(value)

proc put(stream: OutputStreamHandle, value: object) {.inline.}

proc encodeField(stream: OutputStreamHandle, fieldNum: int, value: object) =
  # This is currently needed in order to get the size
  # of the output before adding it to the stream.
  # Maybe there is a better way to do this
  let objStream = memoryOutput()
  objStream.put(value)

  let objOutput = objStream.s.getOutput()
  if objOutput.len > 0:
    stream.s.cursor.append protoHeader(fieldNum, LengthDelimited)
    stream.put(objOutput)

proc put(stream: OutputStreamHandle, value: object) =
  var fieldNum = 1
  value.enumInstanceSerializedFields(_, val):
    if default(type(val)) != val:
      stream.encodeField(fieldNum, val)
    inc fieldNum

proc encode*(protobuf: var ProtoBuffer, value: object) =
  protobuf.outstream.put(value)

proc encodeField*(protobuf: var ProtoBuffer, fieldNum: int, value: AnyProtoType) =
  protobuf.outstream.encodeField(fieldNum, value)

proc encodeField*(protobuf: var ProtoBuffer, value: AnyProtoType) =
  protobuf.encodeField(protobuf.fieldNum, value)
  inc protobuf.fieldNum

proc encodeField[T: not AnyProtoType](stream: OutputStreamHandle, fieldNum: int, value: T) =
  stream.encodeField(fieldNum, value.toProtobuf)

proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, fieldNum: int, value: T) =
  protobuf.outstream.encodeField(fieldNum, value.toProtobuf)

proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, value: T) =
  protobuf.encodeField(protobuf.fieldNum, value.toProtobuf)
  inc protobuf.fieldNum
