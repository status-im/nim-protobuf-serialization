#Writes the specified type into a buffer using the Protobuf binary wire format.

import stew/shims/macros
import faststreams/output_stream
import serialization

import internal
import types

const LAST_BYTE = 0b1111_1111

type ProtobufWriteError* = object of ProtobufError

#Create a field key.
template key(fieldNum: uint, wire: ProtoWireType): byte =
  ((byte(fieldNum shl 3)) or wire.byte).byte

#Get the unsigned absolute value of a number.
#Used when encoding numbers.
template uabs[U](number: VarIntTypes): U =
  if number < type(number)(0):
    not cast[U](number)
  else:
    U(number)

proc writeVarInt(
  stream: OutputStreamHandle,
  fieldNum: uint,
  value: VarIntTypes,
  subtype: VarIntSubType
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

  stream.s.cursor.append(key(fieldNum, VarInt))

  var
    #Get the unsigned value which is what will be encoded.
    raw: U = uabs[U](value)
    #Written bytes.
    #This can be replaced with a countLeadingZeroBits solution so it's O(1), not O(n).
    #That said, while it'd have better complexity, it may not be faster.
    bytesWritten: uint = 0

  #If we're using SInt, we need to transform the value to its zigzagged equivalent.
  if subtype == SIntSubType:
    raw = (raw shl 1) xor (raw shr ((sizeof(raw) * 8) - 1))
    if value < type(value)(0):
      inc(raw)

  #Write the VarInt.
  while raw > type(raw)(VAR_INT_VALUE_MASK):
    #We could convert raw to a byte, but that'll trigger a bounds check.
    stream.s.cursor.append(byte(raw and U(VAR_INT_VALUE_MASK)) or VAR_INT_CONTINUATION_MASK)
    raw = raw shr 7
    inc(bytesWritten)

  #If this was a positive number, or zig-zagged, we only need to write this last byte.
  if (value >= type(value)(0)) or (subtype == SIntSubType):
    stream.s.cursor.append(byte(raw))
  #We need to write blank bytes until the length is 10.
  else:
    stream.s.cursor.append(byte(raw) or VAR_INT_CONTINUATION_MASK)
    while bytesWritten < 9:
      stream.s.cursor.append(VAR_INT_CONTINUATION_MASK)
      inc(bytesWritten)
    stream.s.cursor.append(byte(0))

proc writeFixed64(
  stream: OutputStreamHandle,
  fieldNum: uint,
  value: Fixed64Types
) {.raises: [Defect, IOError].} =
  stream.s.cursor.append(key(fieldNum, Fixed64))
  var raw = cast[uint64](value)
  for _ in 0 ..< 8:
    stream.s.cursor.append(byte(raw and LAST_BYTE))
    raw = raw shr 8

#This has a XDeclaredButNotUsed false positive for some reason.
proc writeValue*[T](value: T): seq[byte] {.raises: [Defect, IOError, ProtobufWriteError].}

proc writeLengthDelimited(
  stream: OutputStreamHandle,
  fieldNum: uint,
  value: LengthDelimitedTypes
) {.raises: [Defect, IOError, ProtobufWriteError].} =
  when type(value) is CastableLengthDelimitedTypes:
    let bytes = cast[seq[byte]](value)
    if bytes.len == 0:
      return
    elif bytes.len > 255:
      raise newException(ProtobufWriteError, "Too long length-delimited buffer when casting a string/seq.")
    stream.s.cursor.append(key(fieldNum, LengthDelimited))
    stream.s.cursor.append(byte(bytes.len))
    for b in bytes:
      stream.s.cursor.append(b)
  elif type(value) is object:
    let bytes = writeValue(value)
    if bytes.len == 0:
      return
    elif bytes.len > 255:
      raise newException(ProtobufWriteError, "Too long length-delimited buffer when handling a nested object.")
    stream.s.cursor.append(key(fieldNum, LengthDelimited))
    stream.s.cursor.append(byte(bytes.len))
    for b in bytes:
      stream.s.cursor.append(b)
  else:
    let bytes = value.toProtobuf()
    if bytes.len == 0:
      return
    elif bytes.len > 255:
      raise newException(ProtobufWriteError, "Too long length-delimited buffer returned from toProtobuf.")
    stream.s.cursor.append(key(fieldNum, LengthDelimited))
    stream.s.cursor.append(byte(bytes.len))
    for b in bytes:
      stream.s.cursor.append(b)

proc writeFixed32(
  stream: OutputStreamHandle,
  fieldNum: uint,
  value: Fixed32Types
) {.raises: [Defect, IOError].} =
  stream.s.cursor.append(key(fieldNum, Fixed32))
  var raw = cast[uint32](value)
  for _ in 0 ..< 4:
    stream.s.cursor.append(byte(raw and LAST_BYTE))
    raw = raw shr 8

proc writeField*[T](
  writer: ProtobufWriter,
  value: T,
  field: static string
) {.raises: [Defect, IOError, ProtobufWriteError].} =
  var counter = 1'u
  enumInstanceSerializedFields(value, fieldName, fieldVar):
    if field != fieldName:
      inc(counter)
    else:
      #Either VarInt of Fixed.
      when fieldVar is VarIntTypes:
        #We need to grab the subtype off the type definition.
        when T.hasCustomPragmaFixed(fieldName, pint):
          writer.stream.writeVarInt(counter, fieldVar, PIntSubType)
        elif T.hasCustomPragmaFixed(fieldName, puint):
          writer.stream.writeVarInt(counter, fieldVar, UIntSubType)
        elif T.hasCustomPragmaFixed(fieldName, sint):
          writer.stream.writeVarInt(counter, fieldVar, SIntSubType)
        #If this is actually a Fixed field, which has a type overlap with VarInt, write it as one.
        elif T.hasCustomPragmaFixed(fieldName, fixed) or T.hasCustomPragmaFixed(fieldName, sfixed):
          when sizeof(fieldVar) == 8:
            writer.stream.writeFixed64(counter, fieldVar)
          else:
            writer.stream.writeFixed32(counter, fieldVar)
        else:
          {.fatal: "Writing a number requires specifying the encoding via a SInt/PIntUInt/Fixed/SFixed wrapping call.".}
      #Float64.
      elif fieldVar is Fixed64Types:
        writer.stream.writeFixed64(counter, fieldVar)
      #Float32.
      elif fieldVar is Fixed32Types:
        writer.stream.writeFixed32(counter, fieldVar)
      #Length delimited.
      else:
        writer.stream.writeLengthDelimited(counter, fieldVar)

proc writeValue*[T](value: T): seq[byte] {.raises: [Defect, IOError, ProtobufWriteError].} =
  let writer: ProtobufWriter = newProtobufWriter()

  when T is VarIntTypes:
    when T is (PIntWrapped32 or PIntWrapped64):
      writer.stream.writeVarInt(1, value.unwrap(), PIntSubType)
    elif T is (UIntWrapped32 or UIntWrapped64):
      writer.stream.writeVarInt(1, value.unwrap(), UIntSubType)
    elif T is (SIntWrapped32 or SIntWrapped64):
      writer.stream.writeVarInt(1, value.unwrap(), SIntSubType)
    elif T is (FixedWrapped64 or SFixedWrapped64):
      writer.stream.writeFixed64(1, value)
    elif T is (FixedWrapped32 or SFixedWrapped32):
      writer.stream.writeFixed32(1, value)
    else:
      {.fatal: "Writing a number requires specifying the encoding via a SInt/PIntUInt/Fixed/SFixed wrapping call.".}
  elif T is Fixed64Types:
    writer.stream.writeFixed64(1, value)
  elif T is Fixed32Types:
    writer.stream.writeFixed32(1, value)
  elif T is object:
    enumInstanceSerializedFields(value, fieldName, _):
      writer.writeField(value, fieldName)
  else:
    writer.stream.writeLengthDelimited(1, value)

  return writer.buffer()
