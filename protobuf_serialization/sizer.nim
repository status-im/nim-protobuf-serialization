{.push raises: [], gcsafe.}

import
  std/[typetraits],
  stew/shims/macros,
  serialization,
  ./[codec, internal, types]

func computeObjectSize*[T: object](value: T): int

func computeFieldSize*[T: not openArray and not PBOption](
    field: int, value: T, ProtoType: type ProtobufExt,
    _: static bool) =
  unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

func computeFieldSizePacked*(
    field: int, values: openArray, ProtoType: type ProtobufExt): int =
  unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

func computeFieldSize*[T: object and not PBOption](
    field: int, value: T, ProtoType: type pbytes,
    skipDefault: static bool): int =
  let
    size = computeObjectSize(value)

  when skipDefault:
    if size == 0:
      return 0

  computeSize(FieldHeader.init(field, ProtoType.wireKind())) +
    computeSize(puint64(size)) +
    size

func computeFieldSize*[T: not object and (seq[byte] or not seq)](
    field: int, value: T,
    ProtoType: type SomeScalar, skipDefault: static bool): int =
  when skipDefault:
    const def = default(typeof(value))
    if value == def:
      return

  computeSize(field, ProtoType(value))

func computeFieldSize*(
    field: int, value: PBOption, ProtoType: type,
    skipDefault: static bool): int =
  if value.isSome(): # TODO required field checking
    computeFieldSize(field, value.get(), ProtoType, skipDefault)
  else:
    0

when defined(ConformanceTest):
  func computeFieldSize*[T](
    field: int, value: ref T,
    ProtoType: type pbytes, skipDefault: static bool): int =
    if not value.isNil():
      computeFieldSize(field, value[], ProtoType, skipDefault)
    else:
      0

func computeFieldSize*[T: not byte](
    field: int, 
    value: openArray[T],
    ProtoType: type, # SomeProto,
    skipDefault: static bool
): int =
  var dataSize = 0
  for i in 0 ..< value.len:
    # don't skip defaults so as to preserve length
    dataSize += computeFieldSize(field, value[i], ProtoType, false)
  dataSize

func computeSizePacked*[T: not byte](
    value: openArray[T], ProtoType: type SomePrimitive): int =
  const canCopyMem =
    ProtoType is SomeFixed32 or ProtoType is SomeFixed64 or ProtoType is pbool
  when canCopyMem:
    value.len() * sizeof(T)
  else:
    var total = 0
    for item in value:
      total += computeSize(ProtoType(item))
    total

func computeFieldSizePacked*(
    field: int, value: openArray, ProtoType: type SomePrimitive): int =
  # Packed encoding uses a length-delimited field byte length of the sum of the
  # byte lengths of each field followed by the header-free contents
  if value.len == 0:
    return 0
  let
    dataSize = computeSizePacked(value, ProtoType)

  computeSize(FieldHeader.init(field, WireKind.LengthDelim)) +
    computeSize(puint64(dataSize)) +
    dataSize

func computeObjectSize*[T: object](value: T): int =
  mixin supportsPacked, computeFieldSizePacked, computeFieldSize

  const
    isProto2: bool = T.isProto2()
    isProto3: bool = T.isProto3()
  static:
    doAssert isProto2 xor isProto3

  var total = 0
  enumInstanceSerializedFields(value, fieldName, fieldVal):
    const
      fieldNum = T.fieldNumberOf(fieldName)
      isPacked = T.isPacked(fieldName).get(isProto3)

    protoType(ProtoType, T, typeof(fieldVal), fieldName)

    let fieldSize =
      when isPacked and supportsPacked(typeof(fieldVal), ProtoType):
        computeFieldSizePacked(fieldNum, fieldVal, ProtoType)
      else:
        computeFieldSize(fieldNum, fieldVal, ProtoType, isProto3)

    total += fieldSize

  total
