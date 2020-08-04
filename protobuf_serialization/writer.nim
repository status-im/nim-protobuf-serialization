#Writes the specified type into a buffer using the Protobuf binary wire format.

import options

import stew/shims/macros
import faststreams/outputs
import serialization

import internal
import types

proc writeVarInt(
  stream: OutputStream,
  fieldNum: int,
  value: VarIntWrapped,
  omittable: static bool
) =
  let bytes = encodeVarInt(value)
  when omittable:
    if (bytes.len == 1) and (bytes[0] == 0):
      return
  stream.writeProtobufKey(fieldNum, VarInt)
  stream.write(bytes)

proc writeFixed(
  stream: OutputStream,
  fieldNum: int,
  value: auto,
  omittable: static bool
) =
  when sizeof(value) == 8:
    let wire = Fixed64
  else:
    let wire = Fixed32
  when omittable:
    if value.unwrap() == 0:
      return

  stream.writeProtobufKey(fieldNum, wire)
  stream.encodeFixed(value)

proc writeValueInternal[T](stream: OutputStream, value: T)

#stdlib types toProtobuf's. inlined as it needs access to the writeValue function.
include stdlib_writers

proc writeLengthDelimited[T](
  stream: OutputStream,
  fieldNum: int,
  rootType: typedesc[T],
  fieldName: static string,
  flatValue: LengthDelimitedTypes,
  omittable: static bool
) =
  const stdlib = type(flatValue).isStdlib()

  var cursor = stream.delayVarSizeWrite(10)
  let startPos = stream.pos

  #Byte seqs.
  when flatValue is CastableLengthDelimitedTypes:
    if flatValue.len == 0:
      cursor.finalWrite([])
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
    when omittable:
      cursor.finalWrite([])
    else:
      cursor.finalWrite(newProtobufKey(fieldNum, LengthDelimited) & encodeVarInt(PInt(int32(0))))

proc writeFieldInternal[T, R](
  stream: OutputStream,
  fieldNum: int,
  value: T,
  rootType: typedesc[R],
  fieldName: static string
) =
  when flatType(value) is SomeFloat:
    when rootType.hasCustomPragmaFixed(fieldName, pfloat32):
      static: verifySerializable(type(Float32(value)))
    elif rootType.hasCustomPragmaFixed(fieldName, pfloat64):
      static: verifySerializable(type(Float64(value)))
    else:
      {.fatal: "Float in object did not have an encoding pragma attached.".}
  else:
    static: verifySerializable(flatType(T))

  let flattenedOption = value.flatMap()
  if flattenedOption.isNone():
    return
  let flattened = flattenedOption.get()

  when (flatType(R) is not object) or (flatType(R).isStdlib()):
    const omittable: bool = true
  else:
    when R is Option:
      {.fatal: "Can't directly write an Option of an object.".}
    const omittable: bool = (
      (fieldName == "") or
      (flatType(T).isStdlib()) or
      rootType.hasCustomPragma(protobuf3)
    )

  when flattened is VarIntWrapped:
    stream.writeVarInt(fieldNum, flattened, omittable)
  elif flattened is FixedWrapped:
    stream.writeFixed(fieldNum, flattened, omittable)
  else:
    stream.writeLengthDelimited(fieldNum, R, fieldName, flattened, omittable)

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
              hasFixed = flatType(value).hasCustomPragmaFixed(fieldName, fixed)
            when hasPInt:
              stream.writeFieldInternal(fieldNum, PInt(flattenedField), type(value), fieldName)
            elif hasSInt:
              stream.writeFieldInternal(fieldNum, SInt(flattenedField), type(value), fieldName)
            elif hasFixed:
              stream.writeFieldInternal(fieldNum, Fixed(flattenedField), type(value), fieldName)
            else:
              {.fatal: "Encoding pragma specified yet no enoding matched. This should never happen.".}

          elif flattenedField is FixedTypes:
            stream.writeFieldInternal(fieldNum, flattenedField, type(value), fieldName)

          else:
            {.fatal: "Attempting to handle an unknown number type. This should never happen.".}
        else:
          when flattenedField is enum:
            stream.writeFieldInternal(fieldNum, PInt(flattenedField), type(value), fieldName)
          else:
            stream.writeFieldInternal(fieldNum, flattenedField, type(value), fieldName)
  else:
    stream.writeFieldInternal(1, flattened, type(value), "")

proc writeValue*[T](writer: ProtobufWriter, value: T) =
  var
    cursor: VarSizeWriteCursor
    startPos: int

  if (
    writer.flags.contains(VarIntLengthPrefix) or
    writer.flags.contains(UIntLELengthPrefix) or
    writer.flags.contains(UIntBELengthPrefix)
  ):
    cursor = writer.stream.delayVarSizeWrite(5)
    startPos = writer.stream.pos

  writer.stream.writeValueInternal(value)

  if (
    writer.flags.contains(VarIntLengthPrefix) or
    writer.flags.contains(UIntLELengthPrefix) or
    writer.flags.contains(UIntBELengthPrefix)
  ):
    var len = uint32(writer.stream.pos - startPos)
    if len == 0:
      cursor.finalWrite([])
    elif writer.flags.contains(VarIntLengthPrefix):
      var viLen = encodeVarInt(PInt(len))
      if viLen.len == 0:
        cursor.finalWrite([byte(0)])
      else:
        cursor.finalWrite(viLen)
    elif writer.flags.contains(UIntLELengthPrefix):
      var temp: array[sizeof(len), byte]
      for i in 0 ..< sizeof(len):
        temp[i] = byte(len and LAST_BYTE)
        len = len shr 8
      cursor.finalWrite(temp)
    elif writer.flags.contains(UIntBELengthPrefix):
      var temp: array[sizeof(len), byte]
      for i in 0 ..< sizeof(len):
        temp[i] = byte(len shr ((sizeof(len) - 1) * 8))
        len = len shl 8
      cursor.finalWrite(temp)
