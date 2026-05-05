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
    static: doAssert FlatType isnot T
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

    enumInstanceSerializedFields(inst, fieldName, fieldVar):
      when isProto2 and not T.isRequired(fieldName) and
          fieldVar isnot (seq or PBOption) and
          not isExtension(Protobuf, typeof(fieldVar)):
        fieldError T, fieldName, "proto2 requires every field to either have the required pragma attached or be a repeated field/PBOption."
      when isProto3 and (
        T.hasCustomPragmaFixed(fieldName, required) or
        fieldVar is PBOption or
        isExtension(Protobuf, typeof(fieldVar))
      ):
        fieldError T, fieldName, "The required pragma/PBOption type can only be used with proto2."

      protoType(ProtoType {.used.}, T, typeof(fieldVar), fieldName) # Ensure we can form a ProtoType

      const fieldNum = T.fieldNumberOf(fieldName)
      when not validFieldNumber(fieldNum, strict = true):
        fieldError T, fieldName, "Field numbers must be in the range [1..2^29-1]"

      if fieldNumberSet.containsOrIncl(fieldNum):
        raiseAssert $T & "." & fieldName & ": Field number was used twice on two different fields: " & $fieldNum

      type FieldType = typeof(fieldVar)
      when FieldType is object and T.hasCustomPragmaFixed(fieldName, ext):
        discard  # do nothing for object extensions
      else:
        verifySerializable(FieldType)
