#Included by writer.

import sets
import sequtils

import stew/shims/macros

import internal
import types

func encodeNumber[T](value: T): seq[byte] =
  when value is bool:
    result = encodeVarInt(PInt(uint32(value)))
    if result.len == 0:
      result = @[byte(0)]
  elif value is VarIntWrapped:
    result = encodeVarInt(value)
    if result.len == 0:
      result = @[byte(0)]
  elif value is FixedWrapped:
    var unwrapped = value.unwrap()
    for _ in 0 ..< sizeof(unwrapped):
      result.add(byte(unwrapped and 0b1111_1111))
      unwrapped = unwrapped shr 8
  else:
    {.fatal: "Trying to encode a number which isn't wrapped. This should never happen.".}

proc writeValue*[T](writer: ProtobufWriter, value: T) {.inline.}

func stdLibToProtobuf[R](
  _: typedesc[R],
  unusedFieldName: static string,
  value: cstring or string
): seq[byte] {.inline.} =
  cast[seq[byte]]($value)

proc stdlibToProtobuf[R, T](
  ty: typedesc[R],
  fieldName: static string,
  arrInstance: openArray[T]
): seq[byte] =
  type fType = flatType(T)
  for value in arrInstance:
    when fType is (bool or VarIntWrapped or FixedWrapped):
      let possibleNumber = flatMap(value)
      var blank: fType
      result &= encodeNumber(possibleNumber.get(blank))

    elif fType is VarIntTypes:
      when fieldName is "":
        {.fatal: "A standard lib type didn't specify the encoding to use for a number.".}

      let possibleNumber = flatMap(value)
      var blank: fType

      when R.hasCustomPragmaFixed(fieldName, pint):
        result &= encodeNumber(PInt(possibleNumber.get(blank)))
      elif R.hasCustomPragmaFixed(fieldName, sint):
        result &= encodeNumber(SInt(possibleNumber.get(blank)))
      elif R.hasCustomPragmaFixed(fieldName, fixed):
        result &= encodeNumber(Fixed(possibleNumber.get(blank)))

    elif fType is FixedTypes:
      when fieldName is "":
        {.fatal: "A standard lib type didn't specify the encoding to use for a number.".}

      let possibleNumber = flatMap(value)
      var blank: fType
      result &= encodeNumber(Fixed(possibleNumber.get(blank)))

    elif fType is (cstring or string):
      let thisVal = ty.stdlibToProtobuf(fieldName, flatMap(value).get(""))
      result &= byte(thisVal.len) & thisVal

    elif fType is CastableLengthDelimitedTypes:
      let toEncode = flatMap(value).get(T(@[]))
      result &= byte(toEncode.len) & cast[byte](toEncode)

    elif (fType is object) or fType.isStdlib():
      var writer = ProtobufWriter.init(memoryOutput())
      writer.writeValue(value)
      let valueBytes = writer.finish()
      result &= byte(valueBytes.len) & valueBytes

    else:
      {.fatal: "Tried to encode an unrecognized object used in a stdlib type.".}

proc stdlibToProtobuf[R, T](
  ty: typedesc[R],
  fieldName: static string,
  setInstance: set[T]
): seq[byte] =
  var seqInstance: seq[T]
  for value in setInstance:
    seqInstance.add(value)
  result = ty.stdLibToProtobuf(fieldName, seqInstance)

proc stdlibToProtobuf[R, T](
  ty: typedesc[R],
  fieldName: static string,
  setInstance: HashSet[T]
): seq[byte] {.inline.} =
  ty.stdLibToProtobuf(fieldName, setInstance.toSeq())
