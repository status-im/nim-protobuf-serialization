#Writes the specified type into a buffer using the Protobuf binary wire format.

import
  std/typetraits,
  stew/shims/macros,
  faststreams/outputs,
  serialization,
  "."/[codec, internal, types]

export outputs, serialization, codec, types

proc writeValue*[T: object](stream: OutputStream, value: T)

proc writeField(
    stream: OutputStream, fieldNum: int, fieldVal: auto, ProtoType: type UnsupportedType) =
  # TODO turn this into an extension point
  unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

proc writeField*[T: object](stream: OutputStream, fieldNum: int, fieldVal: T) =
  # TODO Pre-compute size of inner object then write it without the intermediate
  #      memory output
  var inner = memoryOutput()
  inner.writeValue(fieldVal)
  let bytes = inner.getOutput()
  stream.writeField(fieldNum, pbytes(bytes))

proc writeField[T: object and not PBOption](
    stream: OutputStream, fieldNum: int, fieldVal: T, ProtoType: type) =
  stream.writeField(fieldNum, fieldVal)

proc writeField[T: not object and not enum](
    stream: OutputStream, fieldNum: int, fieldVal: T, ProtoType: type) =
  stream.writeField(fieldNum, ProtoType(fieldVal))

proc writeField(
    stream: OutputStream, fieldNum: int, fieldVal: PBOption, ProtoType: type) =
  if fieldVal.isSome(): # TODO required field checking
    stream.writeField(fieldNum, fieldVal.get(), ProtoType)

proc writeField[T: enum](
    stream: OutputStream, fieldNum: int, fieldVal: T, ProtoType: type) =
  when 0 notin T:
    {.fatal: $T & " definition must contain a constant that maps to zero".}
  stream.writeField(fieldNum, pint32(fieldVal.ord()))

proc writeFieldPacked*[T: not byte, ProtoType: SomePrimitive](
    output: OutputStream, field: int, values: openArray[T], _: type ProtoType) =
  doAssert validFieldNumber(field)

  # Packed encoding uses a length-delimited field byte length of the sum of the
  # byte lengths of each field followed by the header-free contents
  output.write(
    toBytes(FieldHeader.init(field, WireKind.LengthDelim)))

  const canCopyMem =
    ProtoType is SomeFixed32 or ProtoType is SomeFixed64 or ProtoType is pbool
  let dlength =
    when canCopyMem:
      values.len() * sizeof(T)
    else:
      var total = 0
      for item in values:
        total += vsizeof(ProtoType(item))
      total
  output.write(toBytes(puint64(dlength)))

  when canCopyMem:
    if values.len > 0:
      output.write(
        cast[ptr UncheckedArray[byte]](
          unsafeAddr values[0]).toOpenArray(0, dlength - 1))
  else:
    for value in values:
      output.write(toBytes(ProtoType(value)))

proc writeValue*[T: object](stream: OutputStream, value: T) =
  const
    isProto2: bool = T.isProto2()
    isProto3: bool = T.isProto3()
  static: doAssert isProto2 xor isProto3

  enumInstanceSerializedFields(value, fieldName, fieldVal):
    const
      fieldNum = T.fieldNumberOf(fieldName)

    type
      FlatType = flatType(fieldVal)

    protoType(ProtoType, T, FlatType, fieldName)

    when FlatType is seq and FlatType isnot seq[byte]:
      const
        isPacked = T.isPacked(fieldName).get(isProto3)
      when isPacked and ProtoType is SomePrimitive:
        stream.writeFieldPacked(fieldNum, fieldVal, ProtoType)
      else:
        for i in 0..<fieldVal.len:
          stream.writeField(fieldNum, fieldVal[i], ProtoType)

    elif FlatType is object:
      # TODO avoid writing empty objects in proto3
      stream.writeField(fieldNum, fieldVal, ProtoType)
    else:
      when isProto2:
        stream.writeField(fieldNum, fieldVal, ProtoType)
      else:
        if fieldVal != static(default(typeof(fieldVal))): # TODO make this an extension point?
          stream.writeField(fieldNum, fieldVal, ProtoType)

proc writeValue*[T: object](writer: ProtobufWriter, value: T) =
  static: verifySerializable(T)

  # TODO cursors broken
  # var
  #   cursor: VarSizeWriteCursor
  #   startPos: int

  # if writer.flags.contains(VarIntLengthPrefix):
  #   cursor = writer.stream.delayVarSizeWrite(10)
  #   startPos = writer.stream.pos

  writer.stream.writeValue(value)

  # if writer.flags.contains(VarIntLengthPrefix):
  #   var len = uint32(writer.stream.pos - startPos)
  #   if len == 0:
  #     cursor.finalWrite([])
  #   elif writer.flags.contains(VarIntLengthPrefix):
  #     var viLen = encodeVarInt(PInt(len))
  #     if viLen.len == 0:
  #       cursor.finalWrite([byte(0)])
  #     else:
  #       cursor.finalWrite(viLen)
  #   elif writer.flags.contains(UIntLELengthPrefix):
  #     var temp: array[sizeof(len), byte]
  #     for i in 0 ..< sizeof(len):
  #       temp[i] = byte(len and LAST_BYTE)
  #       len = len shr 8
  #     cursor.finalWrite(temp)
  #   elif writer.flags.contains(UIntBELengthPrefix):
  #     var temp: array[sizeof(len), byte]
  #     for i in 0 ..< sizeof(len):
  #       temp[i] = byte(len shr ((sizeof(len) - 1) * 8))
  #       len = len shl 8
  #     cursor.finalWrite(temp)
