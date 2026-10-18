#Variables needed by the Reader and Writer which should NOT be exported outside of this library.

{.push raises: [], gcsafe.}

import std/[options, sets, setutils]
import stew/shims/macros
export getCustomPragmaFixed, hasCustomPragmaFixed

import serialization

import ./[codec, types, format]

func flatTypeInternal(value: auto): auto {.compileTime.} =
  when value is PBOption:
    flatTypeInternal(value.get())
  else:
    value

template flatType*(T: type Protobuf, value: auto): type =
  typeof(flatTypeInternal(value))

template unsupportedProtoType*(FieldType, RootType, fieldName: untyped): untyped =
  {.fatal: "Serializing " & $FieldType & " as field type is not supported: " & $RootType & "." & fieldName.}

template fieldError(T: type, name, msg: static string) =
  {.fatal: $T & "." & name & ": " & msg.}

func isProto2*(T: type): bool {.compileTime.} = T.hasCustomPragmaFixed(proto2)
func isProto3*(T: type): bool {.compileTime.} = T.hasCustomPragmaFixed(proto3)
func isProto*(T: type): bool {.compileTime.} = T.hasCustomPragmaFixed(proto)

func protoEdition*(T: type): int {.compileTime.} =
  when T.isProto:
    T.getCustomPragmaFixed(proto)
  else:
    0

func isImplicit*(T: type): bool {.compileTime.} =
  T.hasCustomPragmaFixed(implicit)

func isPacked*(
    T: type, fieldName: static string
): Option[bool] {.compileTime.} =
  when T.hasCustomPragmaFixed(fieldName, packed):
    some(T.getCustomPragmaFixed(fieldName, packed))
  else:
    none(bool)

func isRequired*(T: type, fieldName: static string): bool {.compileTime.} =
  T.hasCustomPragmaFixed(fieldName, required)

func isImplicit*(T: type, fieldName: static string): bool {.compileTime.} =
  T.hasCustomPragmaFixed(fieldName, implicit)

func supportsPacked*(T: type, ProtoType: type SomeProto): bool =
  ProtoType is SomePrimitive and T is seq and T isnot seq[byte]

func supportsPacked*(T: type, ProtoType: type ProtobufExt): bool =
  when T is PBOption:
    false
  else:
    unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

template isExtension(T: type Protobuf, FieldType: type): bool = false

func fieldNumberOf*(T: type, fieldName: static string): int {.compileTime.} =
  when T.hasCustomPragmaFixed(fieldName, fieldNumber):
    T.getCustomPragmaFixed(fieldName, fieldNumber)
  else:
    fieldError T, fieldName, "Missing {.fieldNumber: N.}"

func isOneof*(T: type, fieldName: static string): bool {.compileTime.} =
  T.hasCustomPragmaFixed(fieldName, oneof)

func oneofValue[T](values: set[T]): T =
  for value in values:
    return value

macro enumOneofFields*(T: type, kName, kVal, fName, fTyp, body: untyped): untyped =
  result = newStmtList()
  var
    discriminatorCount = 0
    lastBranch: NimNode = nil
    discriminatorName, unselectedValues: NimNode
  for field in T.recordFields:
    if field.caseField == nil:
      if not field.isDiscriminator:
        error $field.name &
          ": unexpected oneof field; must be within a `case` branch", field.name
      if discriminatorCount > 0:
        error $field.name & ": only one `case` is allowed", field.name
      inc discriminatorCount
      let discriminatorTyp = field.typ
      discriminatorName = newLit($field.name)
      unselectedValues = quote do:
        complement({default(typeof(`discriminatorTyp`))})
    else:
      if field.caseBranch == lastBranch:
        error $field.name & ": only one field is allowed per branch", field.name
      let
        fieldName = newLit($field.name)
        fieldTyp = field.typ
        branchValues = field.caseBranchValues
      lastBranch = field.caseBranch
      unselectedValues = infix(unselectedValues, "-", branchValues)
      result.add quote do:
        block:
          const `kName` {.used.} = `discriminatorName`
          const `fName` {.used.} = `fieldName`
          const values = `branchValues`
          when card(values) != 1:
            fieldError `T`, `fName`, "Oneof branch must have exactly one value"
          const `kVal` {.used.} = values.oneofValue
          template `fTyp`(): untyped {.used.} =
            `fieldTyp`
          `body`
  if unselectedValues != nil:
    result.add quote do:
      block:
        const values = `unselectedValues`
        when values != {}:
          fieldError `T`, `discriminatorName`,
            "Oneof branch of non-default value must contain a field: " & $values

macro setOneof*(
    fieldVar: var object, kName: static[string], kVal: untyped, fName: static[string], fVal: untyped
): untyped =
  let kind = ident(kName)
  let field = ident(fName)
  quote do:
    `fieldVar` = typeof(`fieldVar`)(`kind`: `kVal`, `field`: move(`fVal`))

template elementType[T](_: type seq[T]): type = typeof(T)

template protoType*(InnerType, RootType, FieldType: untyped, fieldName: untyped) =
  mixin flatType, isExtension

  when FieldType is seq and FieldType isnot seq[byte]:
    type FlatType = Protobuf.flatType(default(elementType(FieldType)))
  else:
    type FlatType = Protobuf.flatType(default(FieldType))

  const
    isPint = RootType.hasCustomPragmaFixed(fieldName, pint)
    isSint = RootType.hasCustomPragmaFixed(fieldName, sint)
    isFixed = RootType.hasCustomPragmaFixed(fieldName, fixed)
    isInteger =
      (FlatType is int32) or (FlatType is int64) or
      (FlatType is uint32) or (FlatType) is uint64

  when ord(isPint) + ord(isSint) + ord(isFixed) != ord(isInteger):
    when isInteger:
      fieldError RootType, fieldName, "Must specify one of `pint`, `sint` and `fixed`"
    else:
      fieldError RootType, fieldName, "`pint`, `sint` and `fixed` should only be used with integers"

  when RootType.hasCustomPragmaFixed(fieldName, ext) or isExtension(Protobuf, FieldType):
    type InnerType = ProtobufExt[FieldType, RootType, fieldName]
  elif FlatType is float64:
    type InnerType = pdouble
  elif FlatType is float32:
    type InnerType = pfloat
  elif FlatType is int32:
    when isPint:
      type InnerType = pint32
    elif isSint:
      type InnerType = sint32
    else:
      type InnerType = sfixed32
  elif FlatType is int64:
    when isPint:
      type InnerType = pint64
    elif isSint:
      type InnerType = sint64
    else:
      type InnerType = sfixed64
  elif FlatType is uint32:
    when isPint:
      type InnerType = puint32
    elif isSint:
      fieldError RootType, fieldName, "Must not annotate `uint32` fields with `sint`"
    else:
      type InnerType = fixed32
  elif FlatType is uint64:
    when isPint:
      type InnerType = puint64
    elif isSint:
      fieldError RootType, fieldName, "Must not annotate `uint64` fields with `sint`"
    else:
      type InnerType = fixed64
  elif FlatType is bool:
    type InnerType = pbool
  elif FlatType is string:
    type InnerType = pstring
  elif FlatType is seq[byte]:
    type InnerType = pbytes
  #elif FlatType is enum:
  #  type InnerType = penum
  elif FlatType is object:
    type InnerType = pbytes
  elif FlatType is ref and defined(ConformanceTest):
    type InnerType = pbytes
  else:
    unsupportedProtoType(FieldType, RootType, fieldName)

func verifySerializable*[T](ty: typedesc[T]) {.compileTime.} =
  mixin flatType, isExtension

  type FlatType = Protobuf.flatType(default(T))
  when T is PBOption or isExtension(Protobuf, T):
    static: doAssert FlatType isnot T  # avoid infinite recursion
    verifySerializable(FlatType)
  elif FlatType is int | uint:
    {.fatal: $T & ": Serializing a number requires specifying the amount of bits via the type.".}
  elif FlatType is seq:
    when FlatType isnot seq[byte]:
      when defined(ConformanceTest):
        discard # TODO make it work in case of recursivity
        # type List = object (value: Value)
        # type Value = object (list: List)
      else:
        verifySerializable(elementType(FlatType))
  elif FlatType is object:
    var
      inst: T
      fieldNumberSet = initHashSet[int]()
    discard fieldNumberSet
    const
      isProto2 = T.isProto2()
      isProto3 = T.isProto3()
      isProto = T.isProto()
      protoEditions = [2023, 2024, 2026]
    when isProto2.int + isProto3.int + isProto.int != 1:
      {.fatal: $T & ": requires one of {.proto2.}, {.proto3.} or {.proto.}".}
    when isProto and T.protoEdition() notin protoEditions:
      {.fatal: $T & ": invalid edition; must be one of 2023, 2024, or 2026".}
    when T.hasCustomPragmaFixed(oneof):
      {.fatal: $T & ": unexpected oneof value; missing {.oneof.} field?".}

    enumInstanceSerializedFields(inst, fieldName, fieldVal):
      template fieldValTyp(): untyped =
        typeof(fieldVal)

      when T.isOneof(fieldName):
        when T.hasCustomPragmaFixed(fieldName, required):
          fieldError T, fieldName, "Oneof can't be {.required.}"
        elif T.hasCustomPragmaFixed(fieldName, fieldNumber):
          fieldError T, fieldName, "Oneof can't be {.fieldNumber: N.}"
        elif fieldValTyp is seq:
          fieldError T, fieldName, $fieldValTyp & " Oneof can't be seq / repeated"
        elif fieldValTyp is PBOption:
          fieldError T, fieldName, $fieldValTyp & " Oneof can't be PBOption"
        elif fieldValTyp.isProto2().int + fieldValTyp.isProto3().int + fieldValTyp.isProto().int != 1:
          fieldError T, fieldName, $fieldValTyp & " object requires one of {.proto2.}, {.proto3.} or {.proto.}"
        elif fieldValTyp.isProto() and fieldValTyp.protoEdition() notin protoEditions:
          fieldError T, fieldName, $fieldValTyp & " invalid edition; must be one of 2023, 2024, or 2026"
        elif not fieldValTyp.hasCustomPragmaFixed(oneof):
          fieldError T, fieldName, $fieldValTyp & " object missing {.oneof.}"
        enumOneofFields(fieldValTyp, kName, kVal, fName, fTyp):
          when kVal == default(typeof(kVal)):
            fieldError fieldValTyp, fName, "Oneof branch of default value (unset) must not contain any field"
          protoType(ProtoType {.used.}, fieldValTyp, fTyp, fName)
          const fieldNum = fieldValTyp.fieldNumberOf(fName)
          when not validFieldNumber(fieldNum, strict = true):
            fieldError fieldValTyp, fName, "Field numbers must be in the range [1..2^29-1]"
          if fieldNumberSet.containsOrIncl(fieldNum):
            raiseAssert $T & "." & fieldName & ": " & $fieldValTyp & "." & fName & ": Field number was used twice on two different fields: " & $fieldNum
          when fieldValTyp.hasCustomPragmaFixed(fName, ext):
            discard
          elif fTyp is seq and fTyp isnot seq[byte]:
            fieldError fieldValTyp, fName, "Oneof field can't be seq[T] / repeated"
          elif fTyp is PBOption:
            fieldError fieldValTyp, fName, "Oneof field can't be PBOption"
          elif fTyp.hasCustomPragmaFixed(oneof):
            fieldError fieldValTyp, fName, "Oneof field can't be oneof (nested)"
          else:
            verifySerializable(fTyp)
      else:
        const pbFieldTypesCount =
          T.isRequired(fieldName).int +
          (fieldVal is PBOption).int +
          (fieldVal is seq and fieldVal isnot seq[byte]).int
        # XXX pbFieldTypesCount != 1 for strictness
        when isProto2 and pbFieldTypesCount == 0 and
            not isExtension(Protobuf, fieldValTyp):
          fieldError T, fieldName, "field must be one of required, PBOption or seq[T: not byte]"
        when isProto3 and (
          T.isRequired(fieldName) or
          fieldVal is PBOption
        ):
          fieldError T, fieldName, "field must not be required or PBOption in proto3"
        const isEditionFieldTypeValid =
          when T.isImplicit():
            pbFieldTypesCount <= 1
          else:
            T.isImplicit(fieldName).int + pbFieldTypesCount == 1
        when isProto and not isEditionFieldTypeValid and
            not isExtension(Protobuf, fieldValTyp):
          fieldError T, fieldName, "field must be one of implicit, required, PBExplicit or seq[T: not byte]"

        protoType(ProtoType {.used.}, T, fieldValTyp, fieldName) # Ensure we can form a ProtoType

        const fieldNum = T.fieldNumberOf(fieldName)
        when not validFieldNumber(fieldNum, strict = true):
          fieldError T, fieldName, "Field numbers must be in the range [1..2^29-1]"

        if fieldNumberSet.containsOrIncl(fieldNum):
          raiseAssert $T & "." & fieldName & ": Field number was used twice on two different fields: " & $fieldNum

        when T.hasCustomPragmaFixed(fieldName, ext):
          discard  # do nothing for extensions; they should validate on read/write
        else:
          verifySerializable(fieldValTyp)
