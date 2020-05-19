#Included by reader.

import sets

proc readValue*[B](
  bytes: seq[byte],
  ty: typedesc[B]
): B

proc stdlibFromProtobuf*(
  bytes: seq[byte],
  value: var cstring
) {.inline, raises: [].} =
  value = cast[string](bytes)

proc stdlibFromProtobuf*[T](
  bytes: seq[byte],
  seqInstance: var seq[T]
) =
  var index = 0
  while index < bytes.len:
    var len = int(bytes[index])
    inc(index)
    if index + len > bytes.len:
      raise newException(IOError, "Length delimited buffer doesn't have enough data to read the next object.")

    seqInstance.add(bytes[index ..< index + len].readValue(T))
    index += len

proc stdlibFromProtobuf*[C, T](
  bytes: seq[byte],
  arr: var array[C, T]
) =
  var
    count = 0
    index = 0
  while index < bytes.len:
    if count >= C:
      raise newException(IOError, "Length delimited buffer representing an array exceed the array's length.")

    var len = int(bytes[index])
    inc(index)
    if index + len > bytes.len:
      raise newException(IOError, "Length delimited buffer doesn't have enough data to read the next object.")

    arr.add(bytes[index ..< index + len].readValue(T))
    index += len
    inc(count)

proc stdlibFromProtobuf*[T](
  bytes: seq[byte],
  setInstance: var set[T]
) =
  var seqInstance: seq[T]
  bytes.stdlibFromProtobuf(seqInstance)
  for value in seqInstance:
    setInstance.incl(value)

proc stdlibFromProtobuf*[T](
  bytes: seq[byte],
  setInstance: var HashSet[T]
) =
  var seqInstance: seq[T]
  bytes.stdlibFromProtobuf(seqInstance)
  for value in seqInstance:
    setInstance.incl(value)
