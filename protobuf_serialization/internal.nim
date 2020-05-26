#Variables needed by the Reader and Writer which should NOT be exported outside of this library.

import options
import sets
import tables

import stew/shims/macros
#I did try use getCustomPragmaFixed.
#Unfortunately, I couldn't due to fieldNumber resolution errors.
export getCustomPragmaVal
import serialization

import numbers/varint
export varint

import numbers/fixed
export fixed

type
  ProtobufWireType* = enum
    VarInt, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  ProtobufKey* = object
    number*: uint32
    wire*: ProtobufWireType

  #Number types which are platform-dependent and therefore unsafe.
  PlatformDependentTypes* = int or uint

  #Castable length delimited types.
  #These can be directly casted from a seq[byte] and do not require a custom converter.
  CastableLengthDelimitedTypes* = seq[byte or char or bool]
  #This type is literally every other type.
  #Every other type is considered custom, due to the need for their own converters.
  #While cstring/array are built-ins, and therefore should have converters provided, but they still need converters.
  LengthDelimitedTypes* = not (VarIntTypes or FixedTypes)

template isPotentiallyNull*[T](ty: typedesc[T]): bool =
  T is (Option or ref or ptr)

proc flatTypeInternal(value: auto): auto {.compileTime.} =
  when value is Option:
    flatTypeInternal(value.get())
  elif value is (ref or ptr):
    flatTypeInternal(value[])
  else:
    value

template flatType*(value: auto): type =
  type(flatTypeInternal(value))

template flatType*[B](ty: typedesc[B]): type =
  var blank: B
  type(flatType(blank))

proc flatMapInternal[B, T](value: B, ty: typedesc[T]): Option[T] =
  when value is Option:
    if value.isNone():
      return
    flatMapInternal(value.get(), ty)
  elif value is (ref or ptr):
    if value.isNil():
      return
    flatMapInternal(value[], ty)
  else:
    some(value)

template flatMap*(value: auto): auto =
  flatMapInternal(value, flatType(value))

template isStdlib*[B](ty: typedesc[B]): bool =
  flatType(ty) is (cstring or string or seq or array or set or HashSet)

template nextType[B](box: B): auto =
  when B is Option:
    box.get()
  elif B is (ref or ptr):
    box[]
  else:
    box

proc boxInternal[C, B](value: C, into: B): B =
  when value is B:
    value
  elif into is Option:
    var blank: type(nextType(into))
    #We never access this pointer.
    #Ever.
    #That said, in order for this Option to resolve as some, it can't be nil.
    when blank is ref:
      blank = cast[type(blank)](1)
    elif blank is ptr:
      blank = cast[type(blank)](1)
    let temp = some(blank)
    some(boxInternal(value, nextType(temp)))
  elif into is ref:
    new(result)
    result[] = boxInternal(value, nextType(result))
  elif into is ptr:
    result = cast[B](alloc0(sizeof(B)))
    result[] = boxInternal(value, nextType(result))

proc box*[B](into: var B, value: auto) =
  into = boxInternal(value, into)

template fieldNumber*(num: int) {.pragma.}

#Created in response to https://github.com/kayabaNerve/nim-protobuf-serialization/issues/5.
func verifySerializable*[T](ty: typedesc[T]) {.compileTime.} =
  when T is PlatformDependentTypes:
    {.fatal: "Serializing a number requires specifying the amount of bits via the type.".}
  elif T is PureTypes:
    {.fatal: "Serializing a number requires specifying the encoding to use.".}
  elif T.isStdlib():
    discard
  elif T is tuple:
    {.fatal: "Tuples aren't serializable due to the lack of being able to attach pragmas.".}
  elif T is Table:
    {.fatal: "Support for Tables was never added. For more info, see https://github.com/kayabaNerve/nim-protobuf-serialization/issues/4.".}
  #Tuple inclusion is so in case we can add back support for tuples, we solely have to delete the above case.
  elif T is (object or tuple):
    var
      inst: T
      fieldNumberSet = initHashSet[int]()
    enumInstanceSerializedFields(inst, fieldName, fieldVar):
      discard fieldName
      when fieldVar is PlatformDependentTypes:
        {.fatal: "Serializing a number requires specifying the amount of bits via the type.".}
      elif fieldVar is (VarIntTypes or FixedTypes):
        const
          hasPInt = ty.hasCustomPragmaFixed(fieldName, pint)
          hasSInt = ty.hasCustomPragmaFixed(fieldName, sint)
          hasLInt = ty.hasCustomPragmaFixed(fieldName, lint)
          hasFixed = ty.hasCustomPragmaFixed(fieldName, fixed)
        when fieldVar is (VarIntWrapped or FixedWrapped):
          when uint(hasPInt) + uint(hasSInt) + uint(hasLInt) + uint(hasFixed) != 0:
            {.fatal: "Encoding specified for an already wrapped type, or a type which isn't wrappable due to always having one encoding (byte, char, bool, or float).".}
        elif uint(hasPInt) + uint(hasSInt) + uint(hasLInt) + uint(hasFixed) != 1:
            {.fatal: "Couldn't write " & fieldName & "; either none or multiple encodings were specified.".}

      const thisFieldNumber = fieldVar.getCustomPragmaVal(fieldNumber)
      when thisFieldNumber is NimNode:
        {.fatal: "No field number specified on serialized field.".}
      else:
        when thisFieldNumber <= 0:
          {.fatal: "Negative field number or 0 field number was specified. Protobuf fields start at 1.".}
        elif thisFieldNumber shr 28 != 0:
          #I mean, it is technically serializable with an uint64 (max 2^60), or even uint32 (max 2^29).
          #That said, having more than 2^28 fields should never be needed. Why lose performance for a never-useful case?
          {.fatal: "Field number greater than 2^28 specified. On 32-bit systems, this isn't serializable.".}

        if fieldNumberSet.contains(thisFieldNumber):
          raise newException(Exception, "Field number was used twice on two different fields.")
        fieldNumberSet.incl(thisFieldNumber)
