#Writes the specified type into a buffer using the Protobuf binary wire format.

import
  std/typetraits,
  stew/shims/macros,
  faststreams/outputs,
  serialization,
  "."/[codec, internal, sizer, types]

export outputs, serialization, codec, types

proc writeObject[T: object](stream: OutputStream, value: T)

proc writeField*(
    stream: OutputStream, fieldNum: int, fieldVal: auto,
    ProtoType: type UnsupportedType, _: static bool = false) =
  # TODO turn this into an extension point
  unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

proc writeField*[T: object and not PBOption](
    stream: OutputStream, fieldNum: int, fieldVal: T, ProtoType: type pbytes,
    skipDefault: static bool = false) =
  let
    size = computeObjectSize(fieldVal)

  when skipDefault:
    if size == 0:
      return

  stream.writeValue(FieldHeader.init(fieldNum, ProtoType.wireKind()))
  stream.writeValue(puint64(size))
  stream.writeObject(fieldVal)

proc writeField*[T: not object](
    stream: OutputStream, fieldNum: int, fieldVal: T,
    ProtoType: type SomeScalar, skipDefault: static bool = false) =
  when skipDefault:
    const def = default(typeof(fieldVal))
    if fieldVal == def:
      return

  stream.writeField(fieldNum, ProtoType(fieldVal))

proc writeField*(
    stream: OutputStream, fieldNum: int, fieldVal: PBOption, ProtoType: type,
    skipDefault: static bool = false) =
  if fieldVal.isSome():
    stream.writeField(fieldNum, fieldVal.get(), ProtoType, skipDefault)

proc writeFieldPacked*[T: not byte, ProtoType: SomePrimitive](
    output: OutputStream, field: int, values: openArray[T], _: type ProtoType) =
  # Packed encoding uses a length-delimited field byte length of the sum of the
  # byte lengths of each field followed by the header-free contents
  output.write(
    toBytes(FieldHeader.init(field, WireKind.LengthDelim)))

  const canCopyMem =
    ProtoType is SomeFixed32 or ProtoType is SomeFixed64 or ProtoType is pbool
  let
    dataSize = computeSizePacked(values, ProtoType)
  output.write(toBytes(puint64(dataSize)))

  when canCopyMem:
    if values.len > 0:
      output.write(
        cast[ptr UncheckedArray[byte]](
          unsafeAddr values[0]).toOpenArray(0, dataSize - 1))
  else:
    for value in values:
      output.write(toBytes(ProtoType(value)))

proc writeObject[T: object](stream: OutputStream, value: T) =
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
          # don't skip defaults so as to preserve length
          stream.writeField(fieldNum, fieldVal[i], ProtoType, false)
    else:
      stream.writeField(fieldNum, fieldVal, ProtoType, isProto3)

proc writeValue*[T: object](writer: ProtobufWriter, value: T) =
  static: verifySerializable(T)

  if ProtobufFlags.VarIntLengthPrefix in writer.flags:
    let
      size = computeObjectSize(value)
    writer.stream.writeValue(puint64(size))

  writer.stream.writeObject(value)
