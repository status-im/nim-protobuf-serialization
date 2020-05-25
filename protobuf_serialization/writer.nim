#Writes the specified type into a buffer using the Protobuf binary wire format.

import options

import stew/shims/macros
import faststreams/outputs
import serialization

import internal
import types

const LAST_BYTE = 0b1111_1111

proc newProtobufKey(number: int, wire: ProtobufWireType): seq[byte] =
  result = newSeq[byte](10)
  var viLen = 0
  doAssert encodeVarInt(result, viLen, PInt((number shl 3) or int(wire))) == VarIntStatus.Success
  result.setLen(viLen)

proc writeProtobufKey(
  stream: OutputStream,
  number: int,
  wire: ProtobufWireType
) {.inline.} =
  stream.write(newProtobufKey(number, wire))

proc writeVarInt(stream: OutputStream, fieldNum: int, value: VarIntWrapped) =
  let bytes = encodeVarInt(value)
  if (bytes.len == 1) and (bytes[0] == 0):
    return
  stream.writeProtobufKey(fieldNum, VarInt)
  stream.write(bytes)

proc writeFixed(stream: OutputStream, fieldNum: int, value: FixedWrapped) =
  when sizeof(value) == 8:
    var raw = cast[uint64](value)
  else:
    var raw = cast[uint32](value)
  if raw == 0:
    return
  stream.writeProtobufKey(
    fieldNum,
    when sizeof(value) == 8:
      Fixed64
    else:
      Fixed32
  )
  for _ in 0 ..< sizeof(value):
    stream.write(byte(raw and LAST_BYTE))
    raw = raw shr 8

#stdlib types toProtobuf's. inlined as it needs access to the writeValue function.
include stdlib_writers

proc writeValueInternal[T](stream: OutputStream, value: T)

proc writeLengthDelimited[T](
  stream: OutputStream,
  fieldNum: int,
  rootType: typedesc[T],
  fieldName: static string,
  flatValue: LengthDelimitedTypes
) =
  var cursor = stream.delayVarSizeWrite(10)
  let startPos = stream.pos

  #Byte seqs.
  when flatValue is CastableLengthDelimitedTypes:
    if flatValue.len == 0:
      return
    stream.write(cast[seq[byte]](flatValue))

  #Standard lib types which use custom converters, instead of encoding the literal Nim representation.
  elif type(flatValue).isStdlib():
    stream.stdlibToProtobuf(rootType, fieldName, flatValue)

  #Nested object which even if the sub-value is empty, should be encoded as long as it exists.
  elif rootType.isPotentiallyNull():
    writeValueInternal(stream, flatValue)

  #Object which should only be encoded if it has data.
  elif flatValue is (object or tuple):
    writeValueInternal(stream, flatValue)

  else:
    {.fatal: "Tried to write a Length Delimited type which wasn't actually Length Delimited.".}

  if (stream.pos != startPos) or (rootType.isPotentiallyNull()):
    cursor.finalWrite(newProtobufKey(fieldNum, LengthDelimited) & encodeVarInt(PInt(int32(stream.pos - startPos))))
  else:
    cursor.finalWrite([])


proc writeFieldInternal[T, R](
  stream: OutputStream,
  fieldNum: int,
  value: T,
  rootType: typedesc[R],
  fieldName: static string
) =
  static: verifySerializable(flatType(T))

  let flattenedOption = value.flatMap()
  if flattenedOption.isNone():
    return
  let flattened = flattenedOption.get()

  when flattened is bool:
    stream.writeVarInt(fieldNum, PInt(flattened))
  elif flattened is VarIntWrapped:
    stream.writeVarInt(fieldNum, flattened)
  elif flattened is FixedWrapped:
    stream.writeFixed(fieldNum, flattened)
  else:
    stream.writeLengthDelimited(fieldNum, R, fieldName, flattened)

proc writeField*[T](
  writer: ProtobufWriter,
  fieldNum: int,
  value: T
) {.inline.} =
  writer.stream.writeFieldInternal(fieldNum, value, type(value), "")

proc writeValueInternal[T](stream: OutputStream, value: T) =
  static: verifySerializable(flatType(T))

  let flattenedOption = value.flatMap()
  if flattenedOption.isNone():
    return
  let flattened = flattenedOption.get()

  when flatType(value).isStdlib():
    stream.writeFieldInternal(1, flattened, type(value), "")
  elif flattened is (object or tuple):
    enumInstanceSerializedFields(flattened, fieldName, fieldVal):
      discard fieldName
      const fieldNum = getCustomPragmaVal(fieldVal, fieldNumber)
      let flattenedFieldOption = fieldVal.flatMap()
      if flattenedFieldOption.isSome():
        let flattenedField = flattenedFieldOption.get()
        when flattenedField is ((not (VarIntWrapped or FixedWrapped)) and (VarIntTypes or FixedTypes)):
          when flattenedField is SIntegerTypes:
            const
              hasPInt = flatType(value).hasCustomPragmaFixed(fieldName, pint)
              hasSInt = flatType(value).hasCustomPragmaFixed(fieldName, sint)
              hasFixed = flatType(value).hasCustomPragmaFixed(fieldName, fixed)
            when hasPInt:
              stream.writeFieldInternal(fieldNum, PInt(flattenedField), type(value), fieldName)
            elif hasSInt:
              stream.writeFieldInternal(fieldNum, SInt(flattenedField), type(value), fieldName)
            elif hasFixed:
              stream.writeFieldInternal(fieldNum, Fixed(flattenedField), type(value), fieldName)
            else:
              {.fatal: "Either no pragma or unsigned pragma attached to signed field.".}

          elif flattenedField is UIntegerTypes:
            const
              hasPInt = flatType(value).hasCustomPragmaFixed(fieldName, pint) or (flattenedField is bool)
              hasFixed = flatType(value).hasCustomPragmaFixed(fieldName, fixed)
            when hasPInt:
              stream.writeFieldInternal(fieldNum, PInt(flattenedField), type(value), fieldName)
            elif hasFixed:
              stream.writeFieldInternal(fieldNum, Fixed(flattenedField), type(value), fieldName)
            else:
              {.fatal: "Either no pragma or signed pragma attached to unsigned field.".}

          elif flattenedField is FixedTypes:
            const hasFixed = flatType(value).hasCustomPragmaFixed(fieldName, fixed)
            when not hasFixed:
              {.fatal: "Either no pragma or one other than fixed attached to float.".}
            stream.writeFieldInternal(fieldNum, Fixed(flattenedField), type(value), fieldName)

          else:
            {.fatal: "Attempting to handle an unknown number type. This should never happen.".}
        else:
          stream.writeFieldInternal(fieldNum, flattenedField, type(value), fieldName)
  else:
    stream.writeFieldInternal(1, flattened, type(value), "")

proc writeValue*[T](writer: ProtobufWriter, value: T) {.inline.} =
  writer.stream.writeValueInternal(value)
