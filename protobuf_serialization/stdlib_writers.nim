#Included by writer.

import sets
import sequtils

import stew/shims/macros

import internal
import types

proc encodeNumber[T](stream: OutputStream, value: T) =
  when value is bool:
    stream.encodeVarInt(PInt(uint32(value)))
  elif value is VarIntWrapped:
    let pos = stream.pos
    stream.encodeVarInt(value)
  elif value is FixedWrapped:
    var unwrapped = value.unwrap()
    for _ in 0 ..< sizeof(unwrapped):
      stream.write(byte(unwrapped and LAST_BYTE))
      unwrapped = unwrapped shr 8
  else:
    {.fatal: "Trying to encode a number which isn't wrapped. This should never happen.".}

proc writeValue*[T](writer: ProtobufWriter, value: T) {.inline.}

proc stdLibToProtobuf[R](
  stream: OutputStream,
  _: typedesc[R],
  unusedFieldName: static string,
  value: cstring or string
) {.inline.} =
  stream.write(cast[seq[byte]]($value))

proc stdlibToProtobuf[R, T](
  stream: OutputStream,
  ty: typedesc[R],
  fieldName: static string,
  arrInstance: openArray[T]
) =
  type fType = flatType(T)
  for value in arrInstance:
    when fType is (bool or VarIntWrapped or FixedWrapped):
      let possibleNumber = flatMap(value)
      var blank: fType
      stream.encodeNumber(possibleNumber.get(blank))

    elif fType is VarIntTypes:
      when fieldName is "":
        {.fatal: "A standard lib type didn't specify the encoding to use for a number.".}

      let possibleNumber = flatMap(value)
      var blank: fType

      when R.hasCustomPragmaFixed(fieldName, pint):
        stream.encodeNumber(PInt(possibleNumber.get(blank)))
      elif R.hasCustomPragmaFixed(fieldName, sint):
        stream.encodeNumber(SInt(possibleNumber.get(blank)))
      elif R.hasCustomPragmaFixed(fieldName, fixed):
        stream.encodeNumber(Fixed(possibleNumber.get(blank)))

    elif fType is FixedTypes:
      when fieldName is "":
        {.fatal: "A standard lib type didn't specify the encoding to use for a number.".}

      let possibleNumber = flatMap(value)
      var blank: fType
      stream.encodeNumber(Fixed(possibleNumber.get(blank)))

    elif fType is (cstring or string):
      var cursor = stream.delayVarSizeWrite(10)
      let startPos = stream.pos
      stream.stdlibToProtobuf(ty, fieldName, flatMap(value).get(""))
      cursor.finalWrite(encodeVarInt(PInt(int32(stream.pos - startPos))))

    elif fType is CastableLengthDelimitedTypes:
      let toEncode = flatMap(value).get(T(@[]))
      if toEncode.len == 0:
        return
      stream.write(encodeVarInt(PInt(toEncode.len)))
      stream.write(cast[byte](toEncode))

    elif (fType is (object or tuple)) or fType.isStdlib():
      var cursor = stream.delayVarSizeWrite(10)
      let startPos = stream.pos

      var writer = ProtobufWriter.init(stream)
      writer.writeValue(value)

      cursor.finalWrite(encodeVarInt(PInt(int32(stream.pos - startPos))))

    else:
      {.fatal: "Tried to encode an unrecognized object used in a stdlib type.".}

proc stdlibToProtobuf[R, T](
  stream: OutputStream,
  ty: typedesc[R],
  fieldName: static string,
  setInstance: set[T]
) =
  var seqInstance: seq[T]
  for value in setInstance:
    seqInstance.add(value)
  stream.stdLibToProtobuf(ty, fieldName, seqInstance)

proc stdlibToProtobuf[R, T](
  stream: OutputStream,
  ty: typedesc[R],
  fieldName: static string,
  setInstance: HashSet[T]
) {.inline.} =
  stream.stdLibToProtobuf(ty, fieldName, setInstance.toSeq())
