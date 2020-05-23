#Included by writer.

import sets
import sequtils

func encodeNumber[T](value: T): seq[byte] =
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

proc writeValue*[T](writer: ProtobufWriter, value: T) {.inline.}

func stdLibToProtobuf[R](
  _: typedesc[R],
  value: cstring or string
): seq[byte] {.inline.} =
  cast[seq[byte]]($value)

proc stdlibToProtobuf[R, T](
  ty: typedesc[R],
  arrInstance: openArray[T]
): seq[byte] =
  for value in arrInstance:
    when flatType(T) is (bool or VarIntWrapped or FixedWrapped):
      let possibleNumber = flatMap(value)
      var blank: flatType(T)
      result &= encodeNumber(possibleNumber.get(blank))

    elif flatType(T) is (cstring or string):
      let thisVal = ty.stdlibToProtobuf(flatMap(value).get(""))
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

proc stdlibToProtobuf[R, T](ty: typedesc[R], setInstance: set[T]): seq[byte] =
  var seqInstance: seq[T]
  for value in setInstance:
    seqInstance.add(value)
  result = ty.stdLibToProtobuf(seqInstance)

proc stdlibToProtobuf[R, T](
  ty: typedesc[R],
  setInstance: HashSet[T]
): seq[byte] {.inline.} =
  ty.stdLibToProtobuf(setInstance.toSeq())
