#Included by writer.

proc writeValue*[T](
  value: T
): seq[byte]

proc stdlibToProtobuf*[T](
  seqInstance: seq[T]
): seq[byte] =
  for value in seqInstance:
    var valueBytes = writeValue(value)
    if valueBytes.len > 255:
      raise newException(IOError, "Length delimited buffer had too much data.")
    result &= byte(valueBytes.len) & valueBytes
