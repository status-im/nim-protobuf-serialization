#Included by writer.

import sets
import sequtils

proc writeValue*[T](
  value: T
): seq[byte]

proc stdLibToProtobuf*(
  value: cstring
): seq[byte] {.inline, raises: [].}=
  cast[seq[byte]]($value)

proc stdlibToProtobuf*[T](
  arrInstance: openArray[T]
): seq[byte] =
  for value in arrInstance:
    var valueBytes = writeValue(value)
    if valueBytes.len == 0:
      result &= byte(0)
      continue
    elif valueBytes.len > 255:
      raise newException(IOError, "Length delimited buffer had too much data.")

    #Strip out the wire type header.
    result &= byte(valueBytes.len - 1) & valueBytes[1 ..< valueBytes.len]

proc stdlibToProtobuf*[T](
  setInstance: set[T]
): seq[byte] =
  var seqInstance: seq[T]
  for value in setInstance:
    seqInstance.add(value)
  result = seqInstance.stdLibToProtobuf()

proc stdlibToProtobuf*[T](
  setInstance: HashSet[T]
): seq[byte] {.inline.} =
  setInstance.toSeq().stdLibToProtobuf()
