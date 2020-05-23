#Writes the specified type into a buffer using the Protobuf binary wire format.

import options

import stew/shims/macros
import faststreams/outputs
import serialization

import internal
import types

const LAST_BYTE = 0b1111_1111

#Created in response to https://github.com/kayabaNerve/nim-protobuf-serialization/issues/5.
func verifyWritable[T](ty: typedesc[T]) {.compileTime.} =
  when T is PlatformDependentTypes:
    {.fatal: "Writing a number requires specifying the amount of bits via the type.".}
  elif T is ((PureSIntegerTypes or PureUIntegerTypes) and (not bool)):
    {.fatal: "Writing a number requires specifying the encoding to use.".}
  elif T.isStdlib():
    discard
  elif T is object:
    enumInstanceSerializedFields(T(), fieldName, fieldVar):
      discard fieldName
      when fieldVar is PlatformDependentTypes:
        {.fatal: "Writing a number requires specifying the amount of bits via the type.".}
      elif fieldVar is (VarIntTypes or FixedTypes):
        const
          hasPInt = ty.hasCustomPragmaFixed(fieldName, pint)
          hasSInt = ty.hasCustomPragmaFixed(fieldName, sint)
          hasUInt = (ty.hasCustomPragmaFixed(fieldName, puint) or (flatType(fieldVar) is bool))
          hasFixed = ty.hasCustomPragmaFixed(fieldName, fixed)
        when uint(hasPInt) + uint(hasSInt) + uint(hasUInt) + uint(hasFixed) != 1:
          {.fatal: "Couldn't write " & fieldName & "; either none or multiple encodings were specified.".}

    if totalSerializedFields(T) > 32:
      raise newException(Defect, "Object has too many fields; Protobuf has a maximum of 32.")

proc writeProtobufKey*(
  stream: OutputStream,
  number: uint32,
  wire: ProtobufWireType
) {.inline.} =
  stream.write(encodeVarInt(UInt((number shl 3) or uint32(wire))))

proc writeVarInt(stream: OutputStream, fieldNum: uint32, value: VarIntWrapped) =
  let bytes = encodeVarInt(value)
  if (bytes.len == 1) and (bytes[0] == 0):
    return
  stream.writeProtobufKey(fieldNum, VarInt)
  stream.write(bytes)

proc writeFixed(stream: OutputStream, fieldNum: uint32, value: FixedWrapped) =
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
  fieldNum: uint32,
  rootType: typedesc[T],
  flatValue: LengthDelimitedTypes
) =
  var bytes: seq[byte]

  #Byte seqs.
  when flatValue is CastableLengthDelimitedTypes:
    if flatValue.len == 0:
      return
    bytes = cast[seq[byte]](flatValue)

  #Standard lib types which use custom converters, instead of encoding the literal Nim representation.
  elif type(flatValue).isStdlib():
    bytes = flatValue.stdlibToProtobuf()
    if bytes.len == 0:
      return

  #Nested object which even if the sub-value is empty, should be encoded as long as it exists.
  elif rootType.isPotentiallyNull():
    var substream = memoryOutput()
    writeValueInternal(substream, flatValue)
    bytes = substream.getOutput()

  #Object which should only be encoded if it has data.
  elif flatValue is object:
    var substream = memoryOutput()
    writeValueInternal(substream, flatValue)
    bytes = substream.getOutput()
    if bytes.len == 0:
      return

  else:
    {.fatal: "Tried to write a Length Delimited type which wasn't actually Length Delimited.".}

  stream.writeProtobufKey(fieldNum, LengthDelimited)
  stream.write(encodeVarInt(PInt(bytes.len)))
  stream.write(bytes)

proc writeFieldInternal[T, R](
  stream: OutputStream,
  fieldNum: uint32,
  value: T,
  rootType: typedesc[R]
) =
  let flattenedOption = value.flatMap()
  if flattenedOption.isNone():
    return
  let flattened = flattenedOption.get()

  when flattened is bool:
    stream.writeVarInt(fieldNum, UInt(flattened))
  elif flattened is VarIntWrapped:
    stream.writeVarInt(fieldNum, flattened)
  elif flattened is FixedWrapped:
    stream.writeFixed(fieldNum, flattened)
  else:
    writeLengthDelimited(stream, fieldNum, R, flattened)

proc writeField*[T](
  writer: ProtobufWriter,
  fieldNum: uint32,
  value: T
) {.inline.} =
  static: verifySerializable(flatType(T))
  writer.stream.writeFieldInternal(fieldNum, value, type(value))

proc writeValueInternal[T](stream: OutputStream, value: T) =
  let flattenedOption = value.flatMap()
  if flattenedOption.isNone():
    return
  let flattened = flattenedOption.get()

  when flatType(value).isStdlib():
    stream.writeFieldInternal(1'u32, flattened, type(value))
  elif flattened is object:
    var counter = 0'u32
    discard counter
    enumInstanceSerializedFields(flattened, fieldName, fieldVal):
      discard fieldName
      inc(counter)
      let flattenedFieldOption = fieldVal.flatMap()
      if flattenedFieldOption.isSome():
        let flattenedField = flattenedFieldOption.get()
        when flattenedField is VarIntTypes:
          when flattenedField is SIntegerTypes:
            const
              hasPInt = flatType(value).hasCustomPragmaFixed(fieldName, pint)
              hasSInt = flatType(value).hasCustomPragmaFixed(fieldName, sint)
              hasFixed = flatType(value).hasCustomPragmaFixed(fieldName, fixed)
            when hasPInt:
              stream.writeFieldInternal(counter, PInt(flattenedField), type(fieldVal))
            elif hasSInt:
              stream.writeFieldInternal(counter, SInt(flattenedField), type(fieldVal))
            elif hasFixed:
              stream.writeFieldInternal(counter, Fixed(flattenedField), type(fieldVal))
            else:
              {.fatal: "Signed pragma attached to non-signed field.".}

          elif flattenedField is UIntegerTypes:
            const
              hasUInt = (flatType(value).hasCustomPragmaFixed(fieldName, puint) or (flattenedField is bool))
              hasFixed = flatType(value).hasCustomPragmaFixed(fieldName, fixed)
            when hasUInt:
              stream.writeFieldInternal(counter, UInt(flattenedField), type(fieldVal))
            elif hasFixed:
              stream.writeFieldInternal(counter, Fixed(flattenedField), type(fieldVal))
            else:
              {.fatal: "Unsigned pragma attached to non-signed field.".}

          elif flattenedField is FixedTypes:
            const hasFixed = flatType(value).hasCustomPragmaFixed(fieldName, fixed)
            when not hasFixed:
              {.fatal: "Pragma other than fixed attached to float.".}
            stream.writeFieldInternal(counter, Fixed(flattenedField), type(fieldVal))
          else:
            {.fatal: "Attempting to handle an unknown number type. This should never happen.".}
        else:
          stream.writeFieldInternal(counter, flattenedField, type(fieldVal))
  else:
    stream.writeFieldInternal(1'u32, flattened, type(value))

proc writeValue*[T](writer: ProtobufWriter, value: T) {.inline.} =
  static: verifySerializable(type(flatType(T)))
  writer.stream.writeValueInternal(value)
