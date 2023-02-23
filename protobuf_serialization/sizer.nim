import
  std/[typetraits, tables],
  stew/shims/macros,
  serialization,
  "."/[codec, internal, types]

func computeObjectSize*[T: object](value: T): int

func computeFieldSize(
    fieldNum: int, fieldVal: auto, ProtoType: type UnsupportedType,
    _: static bool) =
  # TODO turn this into an extension point
  unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

func computeFieldSize[T: object and not PBOption](
    fieldNum: int, fieldVal: T, ProtoType: type pbytes,
    skipDefault: static bool): int =
  let
    size = computeObjectSize(fieldVal)

  when skipDefault:
    if size == 0:
      return 0

  computeSize(FieldHeader.init(fieldNum, ProtoType.wireKind())) +
    computeSize(puint64(size)) +
    size

proc computeFieldSize*[T: not object](
    fieldNum: int, fieldVal: T,
    ProtoType: type SomeScalar, skipDefault: static bool): int =
  when skipDefault:
    const def = default(typeof(fieldVal))
    if fieldVal == def:
      return

  computeSize(fieldNum, ProtoType(fieldVal))

proc computeFieldSize*(
    fieldNum: int, fieldVal: PBOption, ProtoType: type,
    skipDefault: static bool): int =
  if fieldVal.isSome(): # TODO required field checking
    computeFieldSize(fieldNum, fieldVal.get(), ProtoType, skipDefault)
  else:
    0

when defined(ConformanceTest):
  proc computeFieldSize*[T](
    fieldNum: int, fieldVal: ref T,
    ProtoType: type pbytes, skipDefault: static bool): int =
    if not fieldVal.isNil():
      computeFieldSize(fieldNum, fieldVal[], ProtoType, skipDefault)
    else:
      0

  proc writeField[T: enum](
      stream: OutputStream, fieldNum: int, fieldVal: T, ProtoType: type) =
    when 0 notin T:
      {.fatal: $T & " definition must contain a constant that maps to zero".}
    stream.writeField(fieldNum, pint32(fieldVal.ord()))

  proc computeFieldSize*[K, V](
      fieldNum: int, fieldVal: Table[K, V], ProtoType: type pbytes,
      skipDefault: static bool): int =
    when K is SomePBInt and V is SomePBInt:
      type
        TableObject {.proto3.} = object
          key {.fieldNumber: 1, pint.}: K
          value {.fieldNumber: 2, pint.}: V
    elif K is SomePBInt:
      type
        TableObject {.proto3.} = object
          key {.fieldNumber: 1, pint.}: K
          value {.fieldNumber: 2.}: V
    elif V is SomePBInt:
      type
        TableObject {.proto3.} = object
          key {.fieldNumber: 1.}: K
          value {.fieldNumber: 2, pint.}: V
    else:
      type
        TableObject {.proto3.} = object
          key {.fieldNumber: 1.}: K
          value {.fieldNumber: 2.}: V
    for k, v in fieldVal.pairs():
      let tmp = TableObject(key: k, value: v)
      result += computeFieldSize(fieldNum, tmp, ProtoType, false)

proc computeSizePacked*[T: not byte, ProtoType: SomePrimitive](
    values: openArray[T], _: type ProtoType): int =
  const canCopyMem =
    ProtoType is SomeFixed32 or ProtoType is SomeFixed64 or ProtoType is pbool
  when canCopyMem:
    values.len() * sizeof(T)
  else:
    var total = 0
    for item in values:
      total += computeSize(ProtoType(item))
    total

proc computeFieldSizePacked*[ProtoType: SomePrimitive](
    field: int, values: openArray, _: type ProtoType): int =
  # Packed encoding uses a length-delimited field byte length of the sum of the
  # byte lengths of each field followed by the header-free contents
  let
    dataSize = computeSizePacked(values, ProtoType)

  computeSize(FieldHeader.init(field, WireKind.LengthDelim)) +
    computeSize(puint64(dataSize)) +
    dataSize

func computeObjectSize*[T: object](value: T): int =
  const
    isProto2: bool = T.isProto2()
    isProto3: bool = T.isProto3()
  static:
    doAssert isProto2 xor isProto3

  var total = 0
  enumInstanceSerializedFields(value, fieldName, fieldVal):
    const
      fieldNum = T.fieldNumberOf(fieldName)

    type
      FlatType = flatType(fieldVal)

    protoType(ProtoType, T, FlatType, fieldName)

    let fieldSize = when FlatType is seq and FlatType isnot seq[byte]:
      const
        isPacked = T.isPacked(fieldName).get(isProto3)
      when isPacked and ProtoType is SomePrimitive:
        computeFieldSizePacked(fieldNum, fieldVal, ProtoType)
      else:
        var dataSize = 0
        for i in 0..<fieldVal.len:
          # don't skip defaults so as to preserve length
          dataSize += computeFieldSize(fieldNum, fieldVal[i], ProtoType, false)
        dataSize

    else:
      computeFieldSize(fieldNum, fieldVal, ProtoType, isProto3)

    total += fieldSize

  total
