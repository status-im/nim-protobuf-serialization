#Included by reader.

proc readValue*[B](
  bytes: seq[byte],
  ty: typedesc[B]
): B

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
