#Included by reader.

import sets

import types

proc readValue*(
  reader: ProtobufReader,
  value: var auto
)

proc stdlibFromProtobuf*(
  bytes: seq[byte],
  value: var cstring
) {.inline, raises: [].} =
  value = cast[string](bytes)

proc stdlibFromProtobuf*[T](
  bytes: seq[byte],
  seqInstance: var seq[T]
) =
  var
    index = 0
    blank: T
  let wireByte = T.wireType

  while index < bytes.len:
    let len = int(bytes[index])
    inc(index)

    if len == 0:
      seqInstance.add(blank)
      continue
    elif index + len > bytes.len:
      raise newException(IOError, "Length delimited buffer doesn't have enough data to read the next object.")

    var
      reader: ProtobufReader
      next: T
    reader.init(unsafeMemoryInput(wireByte & bytes[index ..< index + len]))
    reader.readValue(next)
    seqInstance.add(next)
    index += len

proc stdlibFromProtobuf*[C, T](
  bytes: seq[byte],
  arr: var array[C, T]
) =
  var
    count = -1
    index = 0
  let wireByte = T.wireType

  while index < bytes.len:
    if count >= C:
      raise newException(IOError, "Length delimited buffer represents an array exceeding this array's length.")

    let len = int(bytes[index])
    inc(index)
    inc(count)

    if len == 0:
      continue
    if index + len > bytes.len:
      raise newException(IOError, "Length delimited buffer doesn't have enough data to read the next object.")

    var reader: ProtobufReader
    reader.init(unsafeMemoryInput(wireByte & bytes[index ..< index + len]))
    reader.readValue(arr[count])
    index += len

  if count != C - 1:
    raise newException(IOError, "Length delimited buffer was missing elements for this array.")

proc stdlibFromProtobuf*[T](
  bytes: seq[byte],
  setInstance: var (set[T] or HashSet[T])
) =
  var seqInstance: seq[T]
  bytes.stdlibFromProtobuf(seqInstance)
  for value in seqInstance:
    setInstance.incl(value)
