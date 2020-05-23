#Variables needed by the Reader and Writer which should NOT be exported outside of this library.

import options
import sets
import tables

import varint
export varint

type
  ProtobufWireType* = enum
    VarInt, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  ProtobufKey* = object
    number*: uint32
    wire*: ProtobufWireType

  #Number types which are platform-dependent and therefore unsafe.
  PlatformDependentTypes* = int or uint or float

  #Castable length delimited types.
  #These can be directly casted from a seq[byte] and do not require a custom converter.
  CastableLengthDelimitedTypes* = seq[char or byte or uint8 or bool]
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
  flatType(ty) is (cstring or string or seq or array or set or HashSet or Table)

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
