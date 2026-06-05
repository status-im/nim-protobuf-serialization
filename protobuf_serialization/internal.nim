#Variables needed by the Reader and Writer which should NOT be exported outside of this library.

{.push raises: [], gcsafe.}

import std/[options, sets]
import stew/shims/macros
#Depending on the situation, one of these two are used.
#Sometimes, one works where the other doesn't.
#It all comes down to bugs in Nim and managing them.
export getCustomPragmaVal, getCustomPragmaFixed
export hasCustomPragmaFixed

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

proc isProto2*(T: type): bool {.compileTime.} = T.hasCustomPragma(proto2)
proc isProto3*(T: type): bool {.compileTime.} = T.hasCustomPragma(proto3)

proc isPacked*(T: type, fieldName: static string): Option[bool] {.compileTime.} =
  if T.hasCustomPragmaFixed(fieldName, packed):
    const p = T.getCustomPragmaFixed(fieldName, packed)
    when p is NimNode:
      none(bool)
    else:
      some(p)
  else:
    none(bool)

proc isRequired*(T: type, fieldName: static string): bool {.compileTime.} =
  T.hasCustomPragmaFixed(fieldName, required)

proc supportsPacked*(T: type, ProtoType: type SomeProto): bool =
  ProtoType is SomePrimitive and T is seq and T isnot seq[byte]

proc supportsPacked*(T: type, ProtoType: type ProtobufExt): bool =
  when T is PBOption:
    false
  else:
    unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

template isExtension(T: type Protobuf, FieldType: type): bool = false

proc fieldNumberOf*(T: type, fieldName: static string): int {.compileTime.} =
  const fieldNum = T.getCustomPragmaFixed(fieldName, fieldNumber)
  when fieldNum is NimNode:
    fieldError T, fieldName, "Missing {.fieldNumber: N.}"
  else:
    fieldNum

proc isOneof*(T: type, fieldName: static string): bool {.compileTime.} =
  T.hasCustomPragmaFixed(fieldName, oneof)

proc getIdent(n: NimNode): NimNode =
  ## Skip pragmas and `*` and return a fresh ident
  case n.kind
  of nnkPragmaExpr:
    getIdent(n[0])
  of nnkPostfix:
    getIdent(n[1])
  of nnkSym, nnkIdent:
    ident($n)
  else:
    raiseAssert "Expected ident but found: " & $n.kind

macro enumOneofFields*(T: type, kName, kVal, fName, fTyp, body: untyped): untyped =
  result = newStmtList()
  let typeImpl = getType(T)[1].getImpl()
  var discriminatorCount = 0
  var lastBranch: NimNode = nil
  for field in recordFields(typeImpl):
    if field.caseField == nil:
      if not field.isDiscriminator:
        error $typeImpl[0].getIdent() & "." & $field.name.getIdent() & ": unexpected oneof field; field must be within a `case` branch"
      if discriminatorCount > 0:
        error $typeImpl[0].getIdent() & "." & $field.name.getIdent() & ": only one `case` is allowed"
      inc discriminatorCount
    else:
      let discriminatorName = newLit($field.caseField[0].getIdent())
      let fieldName = newLit($field.name.getIdent())
      let fieldTyp = field.typ
      let branchVal = field.caseBranch[0]
      if branchVal == lastBranch:
        error $typeImpl[0].getIdent() & "." & $field.name.getIdent() & ": only one field is allowed per branch"
      lastBranch = branchVal
      result.add quote do:
        block:
          const `kName` {.used.} = `discriminatorName`
          const `fName` {.used.} = `fieldName`
          template `kVal`(): untyped {.used.} =
            `branchVal`
          template `fTyp`(): untyped {.used.} =
            `fieldTyp`
          `body`

macro oneofVar*(fieldVar: var object, fName: static[string]): untyped =
  newDotExpr(fieldVar, ident(fName))

macro setOneof*(
    fieldVar: var object, kName: static[string], kVal: untyped, fName: static[string], fVal: untyped
): untyped =
  let kind = ident(kName)
  let field = ident(fName)
  quote do:
    `fieldVar` = typeof(`fieldVar`)(`kind`: `kVal`, `field`: move(`fVal`))

macro oneofCaseOf*(T: type, value, fVar, fName, body: untyped): untyped =
  var caseStmt = newSeq[NimNode]()
  let typeImpl = getType(T)[1].getImpl()
  for field in recordFields(typeImpl):
    if field.caseField == nil:
      doAssert caseStmt.len == 0
      caseStmt.add newDotExpr(value, field.name.getIdent())
      let enumTyp = field.typ
      let defVal = quote do: default(typeof(`enumTyp`))
      let discardStmt = quote do: discard
      caseStmt.add newTree(nnkOfBranch, defVal, discardStmt)
    else:
      doAssert caseStmt.len > 0
      let branchVal = field.caseBranch[0]
      let fieldName = newLit($field.name.getIdent())
      let fieldVal = newDotExpr(value, field.name.getIdent())
      let body2 = quote do:
        const `fName` {.used.} = `fieldName`
        template `fVar`(): untyped {.used.} =
          `fieldVal`
        `body`
      caseStmt.add newTree(nnkOfBranch, branchVal, body2)
  doAssert caseStmt.len > 0
  newStmtList().add(newTree(nnkCaseStmt, caseStmt))

template protoType*(InnerType, RootType, FieldType: untyped, fieldName: untyped) =
  mixin flatType, isExtension

  when FieldType is seq and FieldType isnot seq[byte]:
    type FlatType = Protobuf.flatType(default(typeof(for a in default(FieldType): a)))
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

template elementType[T](_: type seq[T]): type = typeof(T)

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
    when isProto2 == isProto3:
      {.fatal: $T & ": missing {.proto2.} or {.proto3.}".}
    when T.hasCustomPragma(oneof):
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
        elif fieldValTyp.isProto2() == fieldValTyp.isProto3():
          fieldError T, fieldName, $fieldValTyp & " object requires either {.proto2.} or {.proto3.}"
        elif not fieldValTyp.hasCustomPragma(oneof):
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
          elif fTyp.hasCustomPragma(oneof):
            fieldError fieldValTyp, fName, "Oneof field can't be oneof (nested)"
          else:
            verifySerializable(fTyp)
      else:
        when isProto2 and not T.isRequired(fieldName) and
            fieldVal isnot (seq or PBOption) and
            not isExtension(Protobuf, fieldValTyp):
          fieldError T, fieldName, "proto2 requires every field to either have the required pragma attached or be a repeated field/PBOption."
        when isProto3 and (
          T.hasCustomPragmaFixed(fieldName, required) or
          fieldVal is PBOption or
          isExtension(Protobuf, fieldValTyp)
        ):
          fieldError T, fieldName, "The required pragma/PBOption type can only be used with proto2."

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
