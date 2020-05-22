#Included by writer.

import sets
import sequtils

proc encodeNumber[T](
  value: T
): seq[byte] {.raises: [].} =
  when value is bool:
    result = encodeVarInt(UInt(1'u32))
    if result.len == 0:
      result = @[byte(0)]
  elif value is VarIntWrapped:
    result = encodeVarInt(value)
    if result.len == 0:
      result = @[byte(0)]
  elif value is FixedWrapped:
    let unwrapped = value.unwrap()
    for _ in 0 ..< sizeof(unwrapped):
      result.add(byte(unwrapped and 0b1111_1111))
      unwrapped = unwrapped shr 8
  else:
    {.fatal: "Trying to encode a number which isn't wrapped. This should never happen.".}

proc writeValue*[T](
  writer: ProtobufWriter,
  value: T
) {.raises: [Defect, IOError, ProtobufWriteError].}

proc stdLibToProtobuf*(
  value: cstring or string
): seq[byte] {.inline, raises: [].} =
  cast[seq[byte]]($value)

proc stdlibToProtobuf*[T](
  arrInstance: openArray[T]
): seq[byte] {.raises: [Defect, IOError, ProtobufWriteError].} =
  for value in arrInstance:
    when flatType(T) is (bool or VarIntWrapped or FixedWrapped):
      let possibleNumber = flatMap(value)
      var blank: flatType(T)
      result = encodeNumber(possibleNumber.get(blank))

    elif flatType(T) is (cstring or string):
      let thisVal = flatMap(value).get("").stdlibToProtobuf()
      result &= byte(thisVal.len) & thisVal

    elif flatType(T) is CastableLengthDelimitedTypes:
      let toEncode = flatMap(value).get(T(@[]))
      result &= byte(toEncode.len) & cast[byte](toEncode)

    elif (flatType(T) is object) or flatType(T).isStdlib():
      var writer = ProtobufWriter.init(memoryOutput())
      writer.writeValue(value)
      let valueBytes = writer.finish()
      result &= byte(valueBytes.len) & valueBytes

    else:
      {.fatal: "Tried to encode an unrecognized object used in a stdlib type.".}

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
