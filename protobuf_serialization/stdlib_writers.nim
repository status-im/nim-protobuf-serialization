#Included by writer.

import sets
import sequtils

proc writeValue*[T](
  writer: ProtobufWriter,
  value: T
) {.raises: [Defect, IOError, ProtobufWriteError].}

proc stdLibToProtobuf*(
  value: cstring
): seq[byte] {.inline, raises: [].} =
  cast[seq[byte]]($value)

proc stdlibToProtobuf*[T](
  arrInstance: openArray[T]
): seq[byte] {.raises: [Defect, IOError, ProtobufWriteError].} =
  for value in arrInstance:
    var writer = ProtobufWriter.init(memoryOutput())
    writer.writeValue(value)
    let valueBytes = writer.finish()
    if valueBytes.len == 0:
      result &= byte(0)
      continue
    elif valueBytes.len > 255:
      raise newException(ProtobufWriteError, "Length delimited buffer had too much data.")

    #Strip out the wire type header.
    result &= byte(valueBytes.len - 1) & valueBytes[1 ..< valueBytes.len]

proc stdlibToProtobuf*[T](
  setInstance: set[T]
): seq[byte] {.raises: [Defect, IOError, ProtobufWriteError].} =
  var seqInstance: seq[T]
  for value in setInstance:
    seqInstance.add(value)
  result = seqInstance.stdLibToProtobuf()

proc stdlibToProtobuf*[T](
  setInstance: HashSet[T]
): seq[byte] {.inline, raises: [Defect, IOError, ProtobufWriteError].} =
  setInstance.toSeq().stdLibToProtobuf()
