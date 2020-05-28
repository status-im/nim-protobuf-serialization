#Writes the specified type into a buffer using the Protobuf binary wire format.

import options

import stew/shims/macros
import faststreams/outputs
import serialization

import internal
import types

proc newProtobufKey(number: int, wire: ProtobufWireType): seq[byte] =
  result = newSeq[byte](10)
  var viLen = 0
  doAssert encodeVarInt(
    result,
    viLen,
    PInt((int32(number) shl 3) or int32(wire))
  ) == VarIntStatus.Success
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

proc writeFixed(stream: OutputStream, fieldNum: int, value: auto) =
  when sizeof(value) == 8:
    let wire = Fixed64
  else:
    let wire = Fixed32
  if value.unwrap() == 0:
    return

  stream.writeProtobufKey(fieldNum, wire)
  stream.encodeFixed(value)

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
  const stdlib = type(flatValue).isStdlib()

  var cursor = stream.delayVarSizeWrite(10)
  let startPos = stream.pos

  #Byte seqs.
  when flatValue is CastableLengthDelimitedTypes:
    if flatValue.len == 0:
      return
    stream.write(cast[seq[byte]](flatValue))

  #Standard lib types which use custom converters, instead of encoding the literal Nim representation.
  elif stdlib:
    stream.stdlibToProtobuf(rootType, fieldName, fieldNum, flatValue)

  #Nested object which even if the sub-value is empty, should be encoded as long as it exists.
  elif rootType.isPotentiallyNull():
    writeValueInternal(stream, flatValue)

  #Object which should only be encoded if it has data.
  elif flatValue is (object or tuple):
    writeValueInternal(stream, flatValue)

  else:
    {.fatal: "Tried to write a Length Delimited type which wasn't actually Length Delimited.".}

  const singleBuffer = type(flatValue).singleBufferable()
  if (
    (
      #The underlying type of the standard library container is packable.
      singleBuffer or (
        #This is a object, not a seq or something converted to a seq (stdlib type).
        (not stdlib) and (flatValue is (object or tuple))
      )
    ) and (
      #The length changed, meaning this object is empty.
      (stream.pos != startPos) or
      #The object is empty, yet it exists, which is important as it can not exist.
      rootType.isPotentiallyNull()
    )
  ):
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

  when flattened is VarIntWrapped:
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

  when type(flattened).isStdlib():
    stream.writeFieldInternal(1, flattened, type(value), "")
  elif flattened is (object or tuple):
    enumInstanceSerializedFields(flattened, fieldName, fieldVal):
      discard fieldName
      const fieldNum = getCustomPragmaVal(fieldVal, fieldNumber)
      let flattenedFieldOption = fieldVal.flatMap()
      if flattenedFieldOption.isSome():
        let flattenedField = flattenedFieldOption.get()
        when flattenedField is ((not (VarIntWrapped or FixedWrapped)) and (VarIntTypes or FixedTypes)):
          when flattenedField is VarIntTypes:
            const
              hasPInt = flatType(value).hasCustomPragmaFixed(fieldName, pint)
              hasSInt = flatType(value).hasCustomPragmaFixed(fieldName, sint)
              hasLInt = flatType(value).hasCustomPragmaFixed(fieldName, lint)
              hasFixed = flatType(value).hasCustomPragmaFixed(fieldName, fixed)
            when hasPInt:
              stream.writeFieldInternal(fieldNum, PInt(flattenedField), type(value), fieldName)
            elif hasSInt:
              stream.writeFieldInternal(fieldNum, SInt(flattenedField), type(value), fieldName)
            elif hasLInt:
              stream.writeFieldInternal(fieldNum, LInt(flattenedField), type(value), fieldName)
            elif hasFixed:
              stream.writeFieldInternal(fieldNum, Fixed(flattenedField), type(value), fieldName)
            else:
              {.fatal: "Encoding pragma specified yet no enoding matched. This should never happen.".}

          elif flattenedField is FixedTypes:
            stream.writeFieldInternal(fieldNum, flattenedField, type(value), fieldName)

          else:
            {.fatal: "Attempting to handle an unknown number type. This should never happen.".}
        else:
          stream.writeFieldInternal(fieldNum, flattenedField, type(value), fieldName)
  else:
    stream.writeFieldInternal(1, flattened, type(value), "")

proc writeValue*[T](writer: ProtobufWriter, value: T) {.inline.} =
  writer.stream.writeValueInternal(value)
