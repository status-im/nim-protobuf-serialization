#Included by reader.

import sets

import faststreams

import types

proc decodeNumber[T](stream: InputStream, next: var T) =
  var flattened: flatType(T)
  when flattened is bool:
    next = stream.decodeVarInt(bool, UInt(uint8))
  elif flattened is VarIntWrapped:
    next = stream.decodeVarInt(type(next), type(next))
  elif flattened is FixedWrapped:
    when sizeof(flattened) == 8:
      var temp: uint64
    else:
      var temp: uint32
    for i in 0 ..< sizeof(temp):
      temp = temp + (stream.read() shl (i * 8))
    flattened = cast[type(flattened)](temp)
  else:
    {.fatal: "Trying to decode a number which isn't wrapped. This should never happen.".}
  box(next, flattened)

proc readValue*(reader: ProtobufReader, value: var auto)

proc stdlibFromProtobuf*(stream: InputStream, value: var string) =
  value = newString(stream.totalUnconsumedBytes)
  for c in 0 ..< value.len:
    value[c] = char(stream.read())

proc stdlibFromProtobuf*(stream: InputStream, value: var cstring) =
  var preValue = newString(stream.totalUnconsumedBytes)
  for c in 0 ..< preValue.len:
    preValue[c] = char(stream.read())
  value = preValue

proc stdlibFromProtobuf*[T](stream: InputStream, seqInstance: var seq[T]) =
  var blank: T
  while stream.readable():
    seqInstance.add(blank)

    #This code is shared with the below function.
    #One uses seqInstance[^1], one uses arr[i].
    #This should really be templated out.
    #---
    when flatType(T) is (bool or VarIntWrapped or FixedWrapped):
      stream.decodeNumber(seqInstance[^1])
    elif flatType(T) is (cstring or string):
      var len = stream.decodeVarInt(int, PInt(int32))
      if len < 0:
        raise newException(ProtobufMessageError, "String longer than 2 GB specified.")

      stream.withReadableRange(len, substream):
        substream.stdlibFromProtobuf(seqInstance[^1])
    elif flatType(T) is CastableLengthDelimitedTypes:
      ProtobufReader.init(substream, some(T.wireType), false).readValue(seqInstance[^1])
    elif (flatType(T) is object) or flatType(T).isStdlib():
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

proc stdlibFromProtobuf*[C, T](stream: InputStream, arr: var array[C, T]) =
  when C == 0:
    {.fatal: "Protobuf was told to decode an array of length 0.".}

  var i = 0
  while stream.readable():
    if i >= C:
      raise newException(ProtobufMessageError, "Length delimited buffer represents an array exceeding this array's length.")

    #---
    when flatType(T) is (VarIntWrapped or FixedWrapped):
      stream.decodeNumber(arr[i])
    elif flatType(T) is (cstring or string):
      stream.stdlibFromProtobuf(arr[i])
    elif flatType(T) is CastableLengthDelimitedTypes:
      ProtobufReader.init(substream, some(T.wireType), false).readValue(arr[i])
    elif (flatType(T) is object) or flatType(T).isStdlib():
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

proc stdlibFromProtobuf*[T](
  stream: InputStream,
  setInstance: var (set[T] or HashSet[T])
) =
  var seqInstance: seq[T]
  stream.stdlibFromProtobuf(seqInstance)
  for value in seqInstance:
    setInstance.incl(value)
