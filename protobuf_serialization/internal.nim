#Variables needed by the Reader and Writer which should NOT be exported outside of this library.

import std/sets
import stew/shims/macros
#Depending on the situation, one of these two are used.
#Sometimes, one works where the other doesn't.
#It all comes down to bugs in Nim and managing them.
export getCustomPragmaVal, getCustomPragmaFixed
export hasCustomPragmaFixed

import serialization

import "."/[codec, types]

type UnsupportedType*[FieldType; RootType; fieldName: static string] = object

proc flatTypeInternal(value: auto): auto {.compileTime.} =
  when value is PBOption:
    flatTypeInternal(value.get())
  else:
    value

template flatType*(value: auto): type =
  type(flatTypeInternal(value))

macro unsupportedProtoType*(FieldType, RootType, fieldName: typed): untyped =
  # TODO turn this into an extension point
  # TODO fix RootType printing
  error "Serializing " & humaneTypeName(FieldType) & " as field type is not supported: " & humaneTypeName(RootType) & "." & repr(fieldName)

proc isProto2*(T: type): bool {.compileTime.} = T.hasCustomPragma(protobuf2)
proc isProto3*(T: type): bool {.compileTime.} = T.hasCustomPragma(protobuf3)

proc isPacked*(T: type, fieldName: static string): bool {.compileTime.} =
  T.hasCustomPragmaFixed(fieldName, packed)
proc isRequired*(T: type, fieldName: static string): bool {.compileTime.} =
  T.hasCustomPragmaFixed(fieldName, required)

proc fieldNumberOf*(T: type, fieldName: static string): int {.compileTime.} =
  T.getCustomPragmaFixed(fieldName, fieldNumber)

template protoType*(InnerType, RootType, FieldType: untyped, fieldName: untyped) =
  mixin flatType
  when FieldType is seq and FieldType isnot seq[byte]:
    type FlatType = flatType(default(typeof(for a in default(FieldType): a)))
  else:
    type FlatType = flatType(default(FieldType))
  when FlatType is float64:
    type InnerType = pdouble
  elif FlatType is float32:
    type InnerType = pfloat
  elif FlatType is int32:
    when RootType.hasCustomPragmaFixed(fieldName, pint):
      type InnerType = pint32
    elif RootType.hasCustomPragmaFixed(fieldName, sint):
      type InnerType = sint32
    elif RootType.hasCustomPragmaFixed(fieldName, fixed):
      type InnerType = sfixed32
    else:
      {.fatal: "Must annotate `int32` fields with `pint`, `sint` or `fixed`".}
  elif FlatType is int64:
    when RootType.hasCustomPragmaFixed(fieldName, pint):
      type InnerType = pint64
    elif RootType.hasCustomPragmaFixed(fieldName, sint):
      type InnerType = sint64
    elif RootType.hasCustomPragmaFixed(fieldName, fixed):
      type InnerType = sfixed64
    else:
      {.fatal: "Must annotate `int64` fields with `pint`, `sint` or `fixed`".}
  elif FlatType is uint32:
    when RootType.hasCustomPragmaFixed(fieldName, fixed):
      type InnerType = fixed32
    else:
      type InnerType = puint32
  elif FlatType is uint64:
    when RootType.hasCustomPragmaFixed(fieldName, fixed):
      type InnerType = fixed64
    else:
      type InnerType = puint64
  elif FlatType is bool:
    type InnerType = pbool
  elif FlatType is string:
    type InnerType = pstring
  elif FlatType is seq[byte]:
    type InnerType = pbytes
  elif FlatType is object:
    type InnerType = FieldType
  elif FlatType is enum:
    type InnerType = pint64
  else:
    type InnerType = UnsupportedType[FieldType, RootType, fieldName]

template elementType[T](_: type seq[T]): type = typeof(T)

func verifySerializable*[T](ty: typedesc[T]) {.compileTime.} =
  type FlatType = flatType(default(T))
  when FlatType is int | uint:
    {.fatal: "Serializing a number requires specifying the amount of bits via the type.".}
  elif FlatType is seq:
    verifySerializable(elementType(T))
  elif FlatType is object:
    var
      inst: T
      fieldNumberSet = initHashSet[int]()
    discard fieldNumberSet

    const
      isProto2 = T.isProto2()
      isProto3 = T.isProto3()
    when isProto2 == isProto3:
      {.fatal: "Serialized objects must have either the protobuf2 or protobuf3 pragma attached.".}

    enumInstanceSerializedFields(inst, fieldName, fieldVar):
      when isProto2 and not T.isRequired(fieldName):
        when fieldVar is not seq:
          when fieldVar is not PBOption:
            {.fatal: "Protobuf2 requires every field to either have the required pragma attached or be a repeated field/PBOption.".}
      when isProto3 and (
        T.hasCustomPragmaFixed(fieldName, required) or
        (fieldVar is PBOption)
      ):
        {.fatal: "The required pragma/PBOption type can only be used with Protobuf2.".}

      protoType(ProtoType, T, typeof(fieldVar), fieldName) # Ensure we can form a ProtoType

      const fieldNum = T.fieldNumberOf(fieldName)
      when fieldNum is NimNode:
        {.fatal: "No field number specified on serialized field.".}
      else:
        when not validFieldNumber(fieldNum):
          {.fatal: "Field numbers must be in the range [1..2^29-1]".}

        if fieldNumberSet.containsOrIncl(fieldNum):
          raiseAssert "Field number was used twice on two different fields: " & $fieldNum

      # verifySerializable(typeof(fieldVar))
