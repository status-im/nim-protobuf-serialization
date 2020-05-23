#Included by reader.

import sets

import stew/shims/macros
import faststreams

import internal
import types

proc decodeNumber[T, E](
  stream: InputStream,
  next: var T,
  encoding: typedesc[E]
) =
  var flattened: flatType(T)
  when flattened is bool:
    flattened = stream.decodeVarInt(bool, UInt(uint32))
  elif E is VarIntWrapped:
    flattened = stream.decodeVarInt(type(flattened), encoding)
  elif E is FixedWrapped:
    when sizeof(flattened) == 8:
      var temp: uint64
    else:
      var temp: uint32
    for i in 0 ..< sizeof(temp):
      temp = temp + (type(temp)(stream.read()) shl (i * 8))
    flattened = cast[type(flattened)](temp)
  else:
    {.fatal: "Trying to decode a number which isn't wrapped. This should never happen.".}
  box(next, flattened)

proc readValue*(reader: ProtobufReader, value: var auto)

proc stdlibFromProtobuf[R](
  stream: InputStream,
  _: typedesc[R],
  unusedFieldName: static string,
  value: var string
) =
  value = newString(stream.totalUnconsumedBytes)
  for c in 0 ..< value.len:
    value[c] = char(stream.read())

proc stdlibFromProtobuf[R](
  stream: InputStream,
  _: typedesc[R],
  unusedFieldName: static string,
  value: var cstring
) =
  var preValue = newString(stream.totalUnconsumedBytes)
  for c in 0 ..< preValue.len:
    preValue[c] = char(stream.read())
  value = preValue

proc stdlibFromProtobuf[R, T](
  stream: InputStream,
  ty: typedesc[R],
  fieldName: static string,
  seqInstance: var seq[T]
) =
  type fType = flatType(T)
  var blank: T
  while stream.readable():
    seqInstance.add(blank)

    #This code is shared with the below function.
    #One uses seqInstance[^1], one uses arr[i].
    #This should really be templated out.
    #---
    when fType is (bool or VarIntWrapped or FixedWrapped):
      stream.decodeNumber(seqInstance[^1], type(seqInstance[^1]))

    elif fType is VarIntTypes:
      when fieldName is "":
        {.fatal: "A standard lib type didn't specify the encoding to use for a number.".}

      when R.hasCustomPragmaFixed(fieldName, pint):
        stream.decodeNumber(seqInstance[^1], PInt(type(seqInstance[^1])))
      elif R.hasCustomPragmaFixed(fieldName, puint):
        stream.decodeNumber(seqInstance[^1], UInt(type(seqInstance[^1])))
      elif R.hasCustomPragmaFixed(fieldName, sint):
        stream.decodeNumber(seqInstance[^1], SInt(type(seqInstance[^1])))
      elif R.hasCustomPragmaFixed(fieldName, fixed):
        stream.decodeNumber(seqInstance[^1], Fixed(type(seqInstance[^1])))

    elif fType is FixedTypes:
      when fieldName is "":
        {.fatal: "A standard lib type didn't specify the encoding to use for a number.".}

      stream.decodeNumber(seqInstance[^1], Fixed(type(seqInstance[^1])))

    elif fType is (cstring or string):
      var len = stream.decodeVarInt(int, PInt(int32))
      if len < 0:
        raise newException(ProtobufMessageError, "String longer than 2 GB specified.")

      stream.withReadableRange(len, substream):
        substream.stdlibFromProtobuf(ty, fieldName, seqInstance[^1])

    elif fType is CastableLengthDelimitedTypes:
      ProtobufReader.init(substream, some(T.wireType), false).readValue(seqInstance[^1])

    elif (fType is object) or fType.isStdlib():
      let len = stream.decodeVarInt(int, PInt32)
      if len < 0:
        raise newException(ProtobufMessageError, "Length delimited buffer contained more than 2 GB of data.")
      elif len == 0:
        continue
      elif not stream.readable(len):
        raise newException(ProtobufEOFError, "Length delimited buffer doesn't have enough data to read the next object.")

      stream.withReadableRange(len, substream):
        ProtobufReader.init(substream, closeAfter = false).readValue(seqInstance[^1])
    else:
      {.fatal: "Tried to decode an unrecognized object used in a stdlib type.".}
    #---

proc stdlibFromProtobuf[R, CRange, T](
  stream: InputStream,
  ty: typedesc[R],
  fieldName: static string,
  arr: var array[CRange, T]
) =
  when CRange is range:
    const
      start = low(CRange)
      C = high(CRange) - low(CRange) + 1
  else:
    const
      start = 0
      C = CRange
  when C == 0:
    {.fatal: "Protobuf was told to decode an array of length 0.".}

  type fType = flatType(T)
  var i = start
  while stream.readable():
    if i >= C:
      raise newException(ProtobufMessageError, "Length delimited buffer represents an array exceeding this array's length.")

    #---
    when fType is (bool or VarIntWrapped or FixedWrapped):
      stream.decodeNumber(arr[i], type(arr[i]))

    elif fType is VarIntTypes:
      when R.hasCustomPragmaFixed(fieldName, pint):
        stream.decodeNumber(arr[i], PInt(type(arr[i])))
      elif R.hasCustomPragmaFixed(fieldName, puint):
        stream.decodeNumber(arr[i], UInt(type(arr[i])))
      elif R.hasCustomPragmaFixed(fieldName, sint):
        stream.decodeNumber(arr[i], SInt(type(arr[i])))
      elif R.hasCustomPragmaFixed(fieldName, fixed):
        stream.decodeNumber(arr[i], Fixed(type(arr[i])))

    elif fType is FixedTypes:
      stream.decodeNumber(arr[i], Fixed(type(arr[i])))

    elif fType is (cstring or string):
      stream.stdlibFromProtobuf(ty, fieldName, arr[i])

    elif fType is CastableLengthDelimitedTypes:
      ProtobufReader.init(substream, some(T.wireType), false).readValue(arr[i])

    elif (fType is object) or fType.isStdlib():
      let len = stream.decodeVarInt(int, PInt32)
      if len < 0:
        raise newException(ProtobufMessageError, "Length delimited buffer contained more than 2 GB of data.")
      elif len == 0:
        continue
      elif not stream.readable(len):
        raise newException(ProtobufEOFError, "Length delimited buffer doesn't have enough data to read the next object.")

      stream.withReadableRange(len, substream):
        ProtobufReader.init(substream, closeAfter = false).readValue(arr[i])
    else:
      {.fatal: "Tried to decode an unrecognized object used in a stdlib type.".}
    #---

    inc(i)

  if i != C:
    raise newException(ProtobufMessageError, "Length delimited buffer was missing elements for this array.")

proc stdlibFromProtobuf[R, T](
  stream: InputStream,
  ty: typedesc[R],
  fieldName: static string,
  setInstance: var (set[T] or HashSet[T])
) =
  var seqInstance: seq[T]
  stream.stdlibFromProtobuf(ty, fieldName, seqInstance)
  for value in seqInstance:
    setInstance.incl(value)
