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
  when E is VarIntWrapped:
    flattened = stream.decodeVarInt(type(flattened), encoding)
  elif E is FixedWrapped:
    stream.decodeFixed(flattened)
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

    when fType is (VarIntWrapped or FixedWrapped):
      stream.decodeNumber(seqInstance[^1], type(seqInstance[^1]))

    elif fType is VarIntTypes:
      when fieldName is "":
        {.fatal: "A standard lib type didn't specify the encoding to use for a number.".}

      when R.hasCustomPragmaFixed(fieldName, pint):
        stream.decodeNumber(seqInstance[^1], PInt(type(seqInstance[^1])))
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

      if not stream.readable(len):
        raise newException(ProtobufEOFError, "Length delimited buffer is bigger than the rest of the stream.")
      stream.withReadableRange(len, substream):
        substream.stdlibFromProtobuf(ty, fieldName, seqInstance[^1])

    elif fType is CastableLengthDelimitedTypes:
      ProtobufReader.init(substream, some(T.wireType), false).readValue(seqInstance[^1])

    elif (fType is object) or fType.isStdlib():
      let len = stream.decodeVarInt(int, PInt(int32))
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
