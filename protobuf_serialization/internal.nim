#Variables needed by the Reader and Writer which should NOT be exported outside of this library.

import options
import sets
import tables

import stew/shims/macros
#Depending on the situation, one of these two are used.
#Sometimes, one works where the other doesn't.
#It all comes down to bugs in Nim and managing them.
export getCustomPragmaVal, getCustomPragmaFixed
export hasCustomPragmaFixed
import serialization

import numbers/varint
export varint

import numbers/fixed
export fixed

const WIRE_TYPE_MASK = 0b0000_0111'i32

type
  ProtobufWireType* = enum
    VarInt, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  ProtobufKey* = object
    number*: int
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

  #Disabled types.
  Disabled = array or cstring or tuple or Table

const DISABLED_STRING = "Arrays, cstrings, tuples, and Tables are not serializable due to various reasons."
discard DISABLED_STRING

template isPotentiallyNull*[T](ty: typedesc[T]): bool =
  T is (Option or ref or ptr)

template getUnderlyingType*[I](
  stdlib: seq[I] or set[I] or HashSet[I]
): untyped =
  type(I)

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
  when B is openArray:
    B
  else:
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

func isStdlib*[B](_: typedesc[B]): bool {.compileTime.} =
  flatType(B) is (cstring or string or seq or array or set or HashSet)

func mustUseSingleBuffer*[T](_: typedesc[T]): bool {.compileTime.}

func convertAndCallMustUseSingleBuffer[T](
  _: typedesc[seq[T] or openArray[T] or set[T] or HashSet[T]]
): bool {.compileTime.} =
  when flatType(T).isStdlib():
    false
  else:
    mustUseSingleBuffer(flatType(T))

#[func convertAndCallMustUseSingleBuffer[C, T](
  _: typedesc[array[C, T]]
): bool {.compileTime.} =
  when flatType(T).isStdlib():
    false
  else:
    mustUseSingleBuffer(flatType(T))]#

func mustUseSingleBuffer*[T](_: typedesc[T]): bool {.compileTime.} =
  when flatType(T) is (cstring or string or seq[byte or char or bool]):
    true
  elif flatType(T) is (array or openArray or set or HashSet):
    flatType(T).convertAndCallMustUseSingleBuffer()
  else:
    false

func singleBufferable*[T](_: typedesc[T]): bool {.compileTime.}

func convertAndCallSingleBufferable[T](
  _: typedesc[seq[T] or openArray[T] or set[T] or HashSet[T]]
): bool {.compileTime.} =
  when flatType(T).isStdlib():
    false
  else:
    singleBufferable(flatType(T))

#[func convertAndCallSingleBufferable[C, T](
  _: typedesc[array[C, T]]
): bool {.compileTime.} =
  when flatType(T).isStdlib():
    false
  else:
    singleBufferable(flatType(T))]#

func singleBufferable*[T](_: typedesc[T]): bool {.compileTime.} =
  when flatType(T).mustUseSingleBuffer():
    true
  elif flatType(T) is (VarIntTypes or FixedTypes):
    true
  elif flatType(T) is (seq or array or openArray or set or HashSet):
    flatType(T).convertAndCallSingleBufferable()
  else:
    false

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
template dontOmit*() {.pragma.}

#Created in response to https://github.com/kayabaNerve/nim-protobuf-serialization/issues/5.
func verifySerializable*[T](ty: typedesc[T]) {.compileTime.} =
  when T is PlatformDependentTypes:
    {.fatal: "Serializing a number requires specifying the amount of bits via the type.".}
  elif T is SomeFloat:
    {.fatal: "Couldnt serialize the float; all floats need their bits specified with a PFloat32 or PFloat64 call.".}
  elif T is PureTypes:
    {.fatal: "Serializing a number requires specifying the encoding to use.".}
  elif T is Disabled:
    {.fatal: DISABLED_STRING & " are not serializable due to various reasons.".}
  elif T.isStdlib():
    discard
  #Tuple inclusion is so in case we can add back support for tuples, we solely have to delete the above case.
  elif T is (object or tuple):
    var
      inst: T
      fieldNumberSet = initHashSet[int]()
    discard fieldNumberSet
    enumInstanceSerializedFields(inst, fieldName, fieldVar):
      discard fieldName
      when fieldVar is PlatformDependentTypes:
        {.fatal: "Serializing a number requires specifying the amount of bits via the type.".}
      elif T is Disabled:
        {.fatal: DISABLED_STRING & " are not serializable due to various reasons.".}
      elif fieldVar is (VarIntTypes or FixedTypes):
        const
          hasPInt = ty.hasCustomPragmaFixed(fieldName, pint)
          hasSInt = ty.hasCustomPragmaFixed(fieldName, sint)
          hasLInt = ty.hasCustomPragmaFixed(fieldName, lint)
          hasFixed = ty.hasCustomPragmaFixed(fieldName, fixed)
        when fieldVar is (VarIntWrapped or FixedWrapped):
          when uint(hasPInt) + uint(hasSInt) + uint(hasLInt) + uint(hasFixed) != 0:
            {.fatal: "Encoding specified for an already wrapped type, or a type which isn't wrappable due to always having one encoding (byte, char, bool, or float).".}

          when fieldVar is SomeFloat:
            const
              hasF32 = ty.hasCustomPragmaFixed(fieldName, pfloat32)
              hasF64 = ty.hasCustomPragmaFixed(fieldName, pfloat64)
            when hasF32:
              when sizeof(fieldVar) != 4:
                {.fatal: "pfloat32 pragma attached to a 64-bit float.".}
            elif hasF64:
              when sizeof(fieldVar) != 8:
                {.fatal: "pfloat64 pragma attached to a 32-bit float.".}
            else:
              {.fatal: "Floats require the pfloat32 or pfloat64 pragma to be attached.".}
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

proc newProtobufKey*(number: int, wire: ProtobufWireType): seq[byte] =
  result = newSeq[byte](10)
  var viLen = 0
  doAssert encodeVarInt(
    result,
    viLen,
    PInt((int32(number) shl 3) or int32(wire))
  ) == VarIntStatus.Success
  result.setLen(viLen)

proc writeProtobufKey*(
  stream: OutputStream,
  number: int,
  wire: ProtobufWireType
) {.inline.} =
  stream.write(newProtobufKey(number, wire))

proc readProtobufKey*(
  stream: InputStream
): ProtobufKey =
  let
    varint = stream.decodeVarInt(int, PInt(int32))
    wire = byte(varint and WIRE_TYPE_MASK)
  if (wire < byte(low(ProtobufWireType))) or (byte(high(ProtobufWireType)) < wire):
    raise newException(ProtobufMessageError, "Protobuf key had an invalid wire type.")
  result.wire = ProtobufWireType(wire)
  result.number = varint shr 3
