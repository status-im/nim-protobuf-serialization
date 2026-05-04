#Writes the specified type into a buffer using the Protobuf binary wire format.

{.push raises: [], gcsafe.}

import
  std/[typetraits],
  stew/shims/macros,
  stew/objects,
  faststreams/outputs,
  serialization,
  ./[codec, internal, sizer, types]

export outputs, serialization, codec, types

proc writeObject[T: object](stream: OutputStream, value: T) {.raises: [IOError].}

proc writeField*[T: not openArray and not PBOption](
    stream: OutputStream, field: int, value: T,
    ProtoType: type ProtobufExt, _: static bool = false) {.raises: [IOError].} =
  unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

proc writeFieldPacked*[T: not byte](
    output: OutputStream, field: int, values: openArray[T], ProtoType: type ProtobufExt) {.raises: [IOError].} =
  unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

proc writeField*[T: object and not PBOption](
    stream: OutputStream, field: int, value: T, ProtoType: type pbytes,
    skipDefault: static bool = false) {.raises: [IOError].} =
  let
    size = computeObjectSize(value)

  when skipDefault:
    if size == 0:
      return

  stream.writeValue(FieldHeader.init(field, ProtoType.wireKind()))
  stream.writeValue(puint64(size))
  stream.writeObject(value)

proc writeField*[T: not object and (seq[byte] or not seq)](
    stream: OutputStream, field: int, value: T,
    ProtoType: type SomeScalar, skipDefault: static bool = false) {.raises: [IOError].} =
  when skipDefault:
    const def = default(typeof(value))
    if value == def:
      return

  stream.writeField(field, ProtoType(value))

proc writeField*[T: not byte](
    stream: OutputStream,
    field: int,
    value: openArray[T],
    ProtoType: type, # SomeProto,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  for i in 0 ..< value.len:
    # don't skip defaults so as to preserve length
    stream.writeField(field, value[i], ProtoType, false)

proc writeFieldPacked*[T: not byte](
    output: OutputStream, field: int, values: openArray[T], ProtoType: type SomePrimitive) {.raises: [IOError].} =
  # Packed encoding uses a length-delimited field byte length of the sum of the
  # byte lengths of each field followed by the header-free contents
  if values.len == 0:
    return

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

proc writeField*(
    stream: OutputStream, field: int, value: PBOption, ProtoType: type,
    skipDefault: static bool = false) {.raises: [IOError].} =
  if value.isSome():
    stream.writeField(field, value.get(), ProtoType, false)

proc writeObject[T: object](stream: OutputStream, value: T) {.raises: [IOError].} =
  mixin supportsPacked, writeFieldPacked

  const
    isProto2: bool = T.isProto2()
    isProto3: bool = T.isProto3()
  static: doAssert isProto2 xor isProto3

  enumInstanceSerializedFields(value, fieldName, fieldVal):
    const
      fieldNum = T.fieldNumberOf(fieldName)
      isPacked = T.isPacked(fieldName).get(isProto3)

    protoType(ProtoType, T, typeof(fieldVal), fieldName)

    when isPacked and supportsPacked(typeof(fieldVal), ProtoType):
      stream.writeFieldPacked(fieldNum, fieldVal, ProtoType)
    elif typeof(fieldVal) is ref and defined(ConformanceTest):
      if not fieldVal.isNil():
        stream.writeField(fieldNum, fieldVal[], ProtoType)
    else:
      stream.writeField(fieldNum, fieldVal, ProtoType, isProto3)

proc writeValue*[T: object](writer: ProtobufWriter, value: T) {.raises: [IOError].} =
  static: verifySerializable(T)

  if ProtobufFlags.VarIntLengthPrefix in writer.flags:
    let
      size = computeObjectSize(value)
    writer.stream.writeValue(puint64(size))

  writer.stream.writeObject(value)
