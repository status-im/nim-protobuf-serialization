#Writes the specified type into a buffer using the Protobuf binary wire format.

import options

import stew/shims/macros
import faststreams/outputs
import serialization

import internal
import types

const LAST_BYTE = 0b1111_1111

type ProtobufWriteError* = object of ProtobufError

#Create a field key.
template key(fieldNum: uint, wire: ProtobufWireType): byte =
  ((byte(fieldNum shl 3)) or wire.byte).byte

#Get the unsigned absolute value of a number.
#Used when encoding numbers.
template uabs[U](number: VarIntTypes): U =
  if number < type(number)(0):
    not cast[U](number)
  else:
    U(number)

#Created in response to https://github.com/kayabaNerve/nim-protobuf-serialization/issues/5.
proc verifyWritable[T](ty: typedesc[T]) {.compileTime.} =
  when T is PlatformDependentTypes:
    {.fatal: "Writing a number requires specifying the amount of bits via the type.".}
  elif T is ((PureSIntegerTypes or PureUIntegerTypes) and (not bool)):
    {.fatal: "Writing a number requires specifying the encoding to use.".}
  elif T is (object or ref):
    enumInstanceSerializedFields(T(), fieldName, fieldVar):
      when fieldVar is PlatformDependentTypes:
        {.fatal: "Writing a number requires specifying the amount of bits via the type.".}

      when fieldVar is (VarIntTypes or SFixedTypes):
        const
          hasPInt = ty.hasCustomPragmaFixed(fieldName, pint)
          hasSInt = ty.hasCustomPragmaFixed(fieldName, sint)
          hasUInt = (ty.hasCustomPragmaFixed(fieldName, puint) or (flatType(fieldVar) is bool))
          hasFixed = ty.hasCustomPragmaFixed(fieldName, fixed)
          hasSFixed = ty.hasCustomPragmaFixed(fieldName, sfixed)
        when uint(hasPInt) + uint(hasSInt) + uint(hasUInt) + uint(hasFixed) + uint(hasSFixed) != 1:
          {.fatal: "Couldn't write " & fieldName & "; either none or multiple encodings were specified.".}

    if totalSerializedFields(T) > 32:
      raise newException(Defect, "Object has too many fields; Protobuf has a maximum of 32.")

proc writeVarInt(
  stream: OutputStream,
  fieldNum: uint,
  value: WrappedVarIntTypes
) {.raises: [Defect, IOError].} =
  when sizeof(value) == 8:
    type U = uint64
  else:
    type U = uint32

  #If the value is 0, don't bother encoding it.
  #This can cause a negative overflow, which will wrap to 0.
  #That's why we use an explicit cast which requires the binary be 0'd.
  if cast[U](value) == 0:
    return

  stream.write(key(fieldNum, VarInt))

  var
    #Get the unsigned value which is what will be encoded.
    raw: U = uabs[U](value.unwrap())
    #Written bytes.
    #This can be replaced with a countLeadingZeroBits solution so it's O(1), not O(n).
    #That said, while it'd have better complexity, it may not be faster.
    bytesWritten: uint = 0

  #If we're using SInt, we need to transform the value to its zig-zagged equivalent.
  if value is SIntWrapped:
    raw = (raw shl 1) xor (raw shr ((sizeof(raw) * 8) - 1))
    if value.unwrap() < 0:
      inc(raw)

  #Write the VarInt.
  while raw > type(raw)(VAR_INT_VALUE_MASK):
    #We could convert raw to a byte, but that'll trigger a bounds check.
    stream.write(byte(raw and U(VAR_INT_VALUE_MASK)) or VAR_INT_CONTINUATION_MASK)
    raw = raw shr 7
    inc(bytesWritten)

  #If this was a positive number, or zig-zagged, we only need to write this last byte.
  if (value.unwrap() >= 0) or (value is SIntWrapped):
    stream.write(byte(raw))
  #We need to write blank bytes until the length is 10.
  else:
    stream.write(byte(raw) or VAR_INT_CONTINUATION_MASK)
    inc(bytesWritten)
    while bytesWritten < 9:
      stream.write(VAR_INT_CONTINUATION_MASK)
      inc(bytesWritten)
    stream.write(byte(0))

proc writeFixed(
  stream: OutputStream,
  fieldNum: uint,
  value: Fixed32Wrapped or Fixed64Wrapped
) {.raises: [Defect, IOError].} =
  when sizeof(value) == 8:
    var raw = cast[uint64](value)
  else:
    var raw = cast[uint32](value)
  if raw == 0:
    return
  stream.write(key(
    fieldNum,
    when sizeof(value) == 8:
      Fixed64
    else:
      Fixed32
  ))
  for _ in 0 ..< sizeof(value):
    stream.write(byte(raw and LAST_BYTE))
    raw = raw shr 8

proc writeValueInternal[T](
  stream: OutputStream,
  value: T,
  sub: bool,
  existingLength: var int
) {.raises: [Defect, IOError, ProtobufWriteError].}

proc writeLengthDelimited[T](
  stream: OutputStream,
  fieldNum: uint,
  rootType: typedesc[T],
  flatValue: LengthDelimitedTypes,
  sub: bool,
  existingLength: var int
) {.raises: [Defect, IOError, ProtobufWriteError].} =
  var bytes: seq[byte]

  if existingLength > 255:
    raise newException(ProtobufWriteError, "Buffer length exceeded 255 when writing a new nested object.")
  if sub:
    existingLength += 2

  #String/byte seqs.
  when flatValue is CastableLengthDelimitedTypes:
    if flatValue.len == 0:
      existingLength -= 2
      return
    bytes = cast[seq[byte]](flatValue)

  #[
  Why do generic types get their own section?
  For the standard lib.
  The standard lib objects are almost always generic.

  By forcing toProtobuf to be called on them, and shipping toProtobufs for stdlib objects,
  we can cleanly add support for stdlib types
  without messy code or worries a new type will break another.
  ]#
  #elif rootType.isGeneric():
  #  bytes = flatValue.toProtobuf()
  #  if bytes.len == 0:
  #    return

  #Nested object which even if the sub-value is empty, should be encoded as long as it exists.
  elif rootType.isPotentiallyNull():
    var substream = memoryOutput()
    writeValueInternal(substream, flatValue, true, existingLength)
    bytes = substream.getOutput()

  #Object which should only be encoded if it has data.
  elif flatValue is object:
    var substream = memoryOutput()
    writeValueInternal(substream, flatValue, true, existingLength)
    bytes = substream.getOutput()
    existingLength -= 2
    if bytes.len == 0:
      return

  #Distinct types.
  else:
    bytes = flatValue.toProtobuf()
    if bytes.len == 0:
      existingLength -= 2
      return

  if not sub:
    existingLength += bytes.len
  if existingLength > 255:
    raise newException(ProtobufWriteError, "Buffer length exceeded 255 when appending data.")

  stream.write(key(fieldNum, LengthDelimited))
  stream.write(byte(bytes.len))
  stream.write(bytes)

proc writeFieldInternal[T](
  stream: OutputStream,
  fieldNum: uint,
  value: T,
  sub: bool,
  existingLength: var int
) {.raises: [Defect, IOError, ProtobufWriteError].} =
  if false:
    raise newException(ProtobufWriteError, "")

  let flattenedOption = value.flatMap()
  if flattenedOption.isNone():
    return
  let flattened = flattenedOption.get()

  when flattened is bool:
    stream.writeVarInt(fieldNum, UInt(flattened))
  elif flattened is WrappedVarIntTypes:
    stream.writeVarInt(fieldNum, flattened)
  elif flattened is (Fixed32Wrapped or Fixed64Wrapped):
    stream.writeFixed(fieldNum, flattened)
  else:
    writeLengthDelimited(stream, fieldNum, T, flattened, sub, existingLength)

proc writeField*[T](
  writer: ProtobufWriter,
  fieldNum: uint,
  value: T
) {.raises: [Defect, IOError, ProtobufWriteError].} =
  static: verifyWritable(flatType(T))
  var existingLength = 0
  writer.stream.writeFieldInternal(fieldNum, value, false, existingLength)

proc writeValueInternal[T](
  stream: OutputStream,
  value: T,
  sub: bool,
  existingLength: var int
) {.raises: [Defect, IOError, ProtobufWriteError].} =
  if false:
    raise newException(ProtobufWriteError, "")
  if false:
    raise newException(IOError, "")

  let flattenedOption = value.flatMap()
  if flattenedOption.isNone():
    return
  let flattened = flattenedOption.get()

  when flattened is object:
    var counter = 0'u
    enumInstanceSerializedFields(flattened, fieldName, fieldVal):
      inc(counter)
      let flattenedFieldOption = fieldVal.flatMap()
      if flattenedFieldOption.isSome():
        let flattenedField = flattenedFieldOption.get()
        when flattenedField is VarIntTypes:
          when flattenedField is SIntegerTypes:
            const
              hasPInt = flatType(value).hasCustomPragmaFixed(fieldName, pint)
              hasSInt = flatType(value).hasCustomPragmaFixed(fieldName, sint)
              hasSFixed = flatType(value).hasCustomPragmaFixed(fieldName, sfixed)
            when hasPInt:
              stream.writeFieldInternal(counter, PInt(flattenedField), sub, existingLength)
            elif hasSInt:
              stream.writeFieldInternal(counter, SInt(flattenedField), sub, existingLength)
            elif hasSFixed:
              stream.writeFieldInternal(counter, SFixed(flattenedField), sub, existingLength)
            else:
              {.fatal: "Signed pragma attached to non-signed field.".}

          elif flattenedField is UIntegerTypes:
            const
              hasUInt = (flatType(value).hasCustomPragmaFixed(fieldName, puint) or (flattenedField is bool))
              hasFixed = flatType(value).hasCustomPragmaFixed(fieldName, fixed)
            when hasUInt:
              stream.writeFieldInternal(counter, UInt(flattenedField), sub, existingLength)
            elif hasFixed:
              stream.writeFieldInternal(counter, Fixed(flattenedField), sub, existingLength)
            else:
              {.fatal: "Unsigned pragma attached to non-signed field.".}

          elif flattenedField is SFixedTypes:
            const hasSFixed = flatType(value).hasCustomPragmaFixed(fieldName, sfixed)
            when hasSFixed:
              stream.writeFieldInternal(counter, SFixed(flattenedField), sub, existingLength)
            else:
              {.fatal: "Pragma other than SFixed attached to float.".}
          else:
            {.fatal: "Attempting to handle unknown number type. This should never happen.".}
        else:
          stream.writeFieldInternal(counter, flattenedField, sub, existingLength)
  else:
    stream.writeFieldInternal(1'u, flattened, sub, existingLength)

proc writeValue*[T](
  value: T
): seq[byte] {.raises: [Defect, IOError, ProtobufWriteError].} =
  static: verifyWritable(type(flatType(T)))
  var
    writer = newProtobufWriter()
    existingLength = 0
  writer.stream.writeValueInternal(value, false, existingLength)
  result = writer.finish()
