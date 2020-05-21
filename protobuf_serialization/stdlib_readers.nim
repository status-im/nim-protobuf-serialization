#Included by reader.

import sets

import faststreams

import types

proc readValue*(
  reader: ProtobufReader,
  value: var auto
)

proc stdlibFromProtobuf*(
  stream: InputStream,
  value: var cstring
) {.inline, raises: [].} =
  var preValue = newString(stream.totalUnconsumedBytes)
  for c in 0 ..< preValue.len:
    preValue[c] = char(stream.read())
  value = preValue

proc stdlibFromProtobuf*[T](
  stream: InputStream,
  seqInstance: var seq[T]
) =
  var blank: T
  let wireByte = T.wireType

  while stream.readable():
    let len = int(stream.read())
    seqInstance.add(blank)
    if len == 0:
      continue
    elif not stream.readable(len):
      raise newException(IOError, "Length delimited buffer doesn't have enough data to read the next object.")

    stream.withReadableRange(len, substream):
      ProtobufReader.initWithWire(wireByte, substream).readValue(seqInstance[^1])

proc stdlibFromProtobuf*[C, T](
  stream: InputStream,
  arr: var array[C, T]
) =
  var count = 0
  let wireByte = T.wireType

  while stream.readable():
    if count >= C:
      raise newException(IOError, "Length delimited buffer represents an array exceeding this array's length.")

    let len = int(stream.read())
    if len == 0:
      continue
    elif not stream.readable(len):
      raise newException(IOError, "Length delimited buffer doesn't have enough data to read the next object.")

    stream.withReadableRange(len, substream):
      ProtobufReader.initWithWire(wireByte, substream).readValue(arr[count])
    inc(count)

  if count != C:
    raise newException(IOError, "Length delimited buffer was missing elements for this array.")

proc stdlibFromProtobuf*[T](
  stream: InputStream,
  setInstance: var (set[T] or HashSet[T])
) =
  var seqInstance: seq[T]
  stream.stdlibFromProtobuf(seqInstance)
  for value in seqInstance:
    setInstance.incl(value)
