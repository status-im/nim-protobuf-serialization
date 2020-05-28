#Included by writer.

import sets
import sequtils

import stew/shims/macros

import internal
import types

proc encodeNumber[T](stream: OutputStream, value: T) =
  when value is VarIntWrapped:
    stream.encodeVarInt(value)
  elif value is FixedWrapped:
    stream.encodeFixed(value)
  else:
    {.fatal: "Trying to encode a number which isn't wrapped. This should never happen.".}

proc writeValue*[T](writer: ProtobufWriter, value: T) {.inline.}

proc stdLibToProtobuf[R](
  stream: OutputStream,
  _: typedesc[R],
  unusedFieldName: static string,
  fieldNumber: int,
  value: cstring or string
) =
  stream.write(cast[seq[byte]]($value))

proc stdlibToProtobuf[R, T](
  stream: OutputStream,
  ty: typedesc[R],
  fieldName: static string,
  fieldNumber: int,
  arrInstance: openArray[T]
) =
  #Get the field number and create a key.
  var key: seq[byte]

  type fType = flatType(T)
  when fType is FixedTypes:
    var hasFixed = false
    when (R is (object or tuple)) and (not R.isStdlib()):
      hasFixed = R.hasCustomPragmaFixed(fieldName, fixed)

  when fType is (VarIntTypes or FixedTypes):
    when fType is FixedTypes:
      if hasFixed:
        key = newProtobufKey(
          fieldNumber,
          when sizeof(fType) == 8:
            Fixed64
          else:
            Fixed32
        )
      else:
        key = newProtobufKey(fieldNumber, VarInt)
    else:
      key = newProtobufKey(fieldNumber, VarInt)
  else:
    key = newProtobufKey(fieldNumber, LengthDelimited)

  const singleBuffer = type(arrInstance).singleBufferable()
  for value in arrInstance:
    if not singleBuffer:
      stream.write(key)

    when fType is (VarIntWrapped or FixedWrapped):
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
      elif R.hasCustomPragmaFixed(fieldName, lint):
        stream.encodeNumber(LInt(possibleNumber.get(blank)))
      elif R.hasCustomPragmaFixed(fieldName, fixed):
        stream.encodeNumber(Fixed(possibleNumber.get(blank)))

    elif fType is FixedTypes:
      when fieldName is "":
        {.fatal: "A standard lib type didn't specify the encoding to use for a number.".}

      let possibleNumber = flatMap(value)
      var blank: fTypeflatType(T)
      stream.encodeNumber(Fixed(possibleNumber.get(blank)))

    elif fType is (cstring or string):
      var cursor = stream.delayVarSizeWrite(10)
      let startPos = stream.pos
      stream.stdlibToProtobuf(ty, fieldName, fieldNumber, flatMap(value).get(""))
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
  fieldNumber: int,
  setInstance: set[T]
) =
  var seqInstance: seq[T]
  for value in setInstance:
    seqInstance.add(value)
  stream.stdLibToProtobuf(ty, fieldName, fieldNumber, seqInstance)

proc stdlibToProtobuf[R, T](
  stream: OutputStream,
  ty: typedesc[R],
  fieldName: static string,
  fieldNumber: int,
  setInstance: HashSet[T]
) {.inline.} =
  stream.stdLibToProtobuf(ty, fieldName, fieldNumber, setInstance.toSeq())
