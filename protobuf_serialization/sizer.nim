{.push raises: [], gcsafe.}

import
  std/[typetraits],
  stew/shims/macros,
  serialization,
  ./[codec, internal, types]

func computeObjectSize*[T: object](value: T): int

func computeFieldSize*[T: not PBOption](
    fieldNum: int, fieldVal: T, ProtoType: type ProtobufExt,
    _: static bool) =
  unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

func computeFieldSize*[T: object and not PBOption](
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

proc computeFieldSize*[T: not object and (seq[byte] or not seq)](
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

proc computeFieldSize*[T: not byte](
    fieldNum: int, fieldVal: openArray[T],
    ProtoType: type SomeProto, skipDefault: static bool): int =
  static: doAssert not skipDefault
  var dataSize = 0
  for i in 0 ..< fieldVal.len:
    # don't skip defaults so as to preserve length
    dataSize += computeFieldSize(fieldNum, fieldVal[i], ProtoType, false)
  dataSize

proc computeSizePacked*[T: not byte](
    values: openArray[T], ProtoType: type SomePrimitive): int =
  const canCopyMem =
    ProtoType is SomeFixed32 or ProtoType is SomeFixed64 or ProtoType is pbool
  when canCopyMem:
    values.len() * sizeof(T)
  else:
    var total = 0
    for item in values:
      total += computeSize(ProtoType(item))
    total

proc computeFieldSizePacked*(
    field: int, values: openArray, ProtoType: type SomePrimitive): int =
  # Packed encoding uses a length-delimited field byte length of the sum of the
  # byte lengths of each field followed by the header-free contents
  if values.len == 0:
    return 0
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

    protoType(ProtoType, T, typeof(fieldVal), fieldName)

    #type
    #  FlatType = flatType(fieldVal)

    let fieldSize = when typeof(fieldVal) is seq and typeof(fieldVal) isnot seq[byte]:
      const
        isPacked = T.isPacked(fieldName).get(isProto3)
      when isPacked and ProtoType is SomePrimitive:
        computeFieldSizePacked(fieldNum, fieldVal, ProtoType)
      else:
        computeFieldSize(fieldNum, fieldVal, ProtoType, false)
    else:
      computeFieldSize(fieldNum, fieldVal, ProtoType, isProto3)

    total += fieldSize

  total
