#Included by writer.

import sets
import sequtils

import faststreams

proc encodeNumber[T](stream: OutputStream, value: T) =
  when value is bool:
    if value:
      stream.write(byte(1))
    else:
      stream.write(byte(0))
  elif value is VarIntWrapped:
    let pos = stream.pos
    stream.encodeVarInt(value)
    if stream.pos == pos:
      stream.write(byte(0))
  elif value is FixedWrapped:
    let unwrapped = value.unwrap()
    for _ in 0 ..< sizeof(unwrapped):
      stream.write(byte(unwrapped and LAST_BYTE))
      unwrapped = unwrapped shr 8
  else:
    {.fatal: "Trying to encode a number which isn't wrapped. This should never happen.".}

proc writeValue*[T](writer: ProtobufWriter, value: T) {.inline.}

proc stdLibToProtobuf*(
  stream: OutputStream,
  value: cstring or string
) {.inline.} =
  stream.write(cast[seq[byte]]($value))

proc stdlibToProtobuf*[T](
  stream: OutputStream,
  arrInstance: openArray[T]
) =
  for value in arrInstance:
    when flatType(T) is (bool or VarIntWrapped or FixedWrapped):
      let possibleNumber = flatMap(value)
      var blank: flatType(T)
      stream.encodeNumber(possibleNumber.get(blank))

    elif flatType(T) is (cstring or string):
      var cursor = stream.delayVarSizeWrite(10)
      let startPos = stream.pos
      stream.stdlibToProtobuf(flatMap(value).get(""))
      cursor.finalWrite(encodeVarInt(UInt(uint32(stream.pos - startPos))))

    elif flatType(T) is CastableLengthDelimitedTypes:
      let toEncode = flatMap(value).get(T(@[]))
      stream.write(byte(toEncode.len))
      stream.write(cast[byte](toEncode))

    elif (flatType(T) is object) or flatType(T).isStdlib():
      var cursor = stream.delayVarSizeWrite(10)
      let startPos = stream.pos

      var writer = ProtobufWriter.init(stream)
      writer.writeValue(value)

      cursor.finalWrite(encodeVarInt(UInt(uint32(stream.pos - startPos))))

    else:
      {.fatal: "Tried to encode an unrecognized object used in a stdlib type.".}

proc stdlibToProtobuf*[T](
  stream: OutputStream,
  setInstance: set[T]
) =
  var seqInstance: seq[T]
  for value in setInstance:
    seqInstance.add(value)
  stream.stdLibToProtobuf(seqInstance)

proc stdlibToProtobuf*[T](
  stream: OutputStream or OutputStream,
  setInstance: HashSet[T]
) {.inline.} =
  stream.stdLibToProtobuf(setInstance.toSeq())
