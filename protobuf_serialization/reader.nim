import options

import stew/shims/macros
import faststreams
import serialization

import types

const
  FIELD_NUMBER_MASK: byte = 0b1111_1000
  WIRE_TYPE_MASK: byte = 0b0000_0111

type
  ProtobufReader* = ref object
    stream: InputStreamHandle

  ProtobufEOFError* = object of ProtobufError
  ProtobufLegacyError* = object of ProtobufError

proc newProtobufReader(
  data: seq[byte]
): ProtobufReader {.inline.} =
  ProtobufReader(stream: memoryInput(data))

template wireType(key: byte): byte =
  key and WIRE_TYPE_MASK

template fieldNumber(key: byte): int =
  (key and FIELD_NUMBER_MASK).int

#Ideally, these would be in a table.
#That said, due to the context specific return type, which goes beyond the wire type, you need generics.
#As Generic types aren't concrete, they can't be used in a table.
proc readVarInt[T](stream: InputStreamHandle, subtype: SubType): T =
  when sizeof(T) == 4:
    type U = uint32
  elif sizeof(T) == 8:
    type U = uint64
  else:
    {.fatal: "Tried to read a VarInt which wasn't 32 or 64 bits.".}

  var
    value = U(0)
    offset: int8 = 0
    next = VAR_INT_CONTINUATION_MASK
  while (next and VAR_INT_CONTINUATION_MASK) != 0:
    let option = stream.next()

    if option.isNone:
      raise newException(ProtobufEOFError, "Couldn't read a VarInt from this stream.")

    next = option.get()
    value += (next and U(VAR_INT_VALUE_MASK)) shl offset
    offset += 7

  #Zig-zagged.
  if subtype in {SInt32, SInt64}:
    if (value and U(0b0000_0001)) == 1:
      result = -T(value shr 1) - 1
    else:
      result = T(value shr 1)
  #Not zig-zagged, yet negative.
  elif offset == 70:
    #This should handle the lowest possible negative value.
    #The cast to a signed value causes it to error/wrap to the lowest value.
    #Said lowest value will be negative, multiplied by -1, and wrap again.
    #This behavior requires boundChecks to be turned off in order to not raise though.
    {.push boundChecks: off.}
    result = -T(value)
    {.pop.}
  #Not zig-zagged, yet positive.
  else:
    result = T(value)

proc readFixed64[T](stream: InputStreamHandle, subtype: SubType): T =
  var
    value: T = T(0)
    next: Option[byte]
  for offset in countup(0, 56, 8):
    next = stream.next()
    if next.isNone():
      raise newException(ProtobufEOFError, "Couldn't read a fixed 64-bit number from this stream.")
    value += T(next.get()) shl T(offset)

proc readLengthDelimited(stream: InputStreamHandle): seq[byte] =
  if not stream.readable():
    raise newException(ProtobufEOFError, "Couldn't read a length delimited sequence from this stream.")

  result = newSeq[byte](stream.next().get())
  for _ in 0 ..< result.len:
    if not stream.readable():
      raise newException(ProtobufEOFError, "Couldn't read a length delimited sequence from this stream.")
    result.add(stream.next().get())

proc readFixed32[T](stream: InputStreamHandle): T =
  var
    value: T = T(0)
    next: Option[byte]
  for offset in countup(0, 24, 8):
    next = stream.next()
    if next.isNone():
      raise newException(ProtobufEOFError, "Couldn't read a fixed 32-bit number from this stream.")
    value += T(next.get()) shl T(offset)

proc getDefaultSubType[T](subtype: SubType): SubType =
  if subtype == Default:
    when (
      (T is Integer32Types) or
      ((T is int) and (sizeof(int) == 4))
    ):
      result = SInt32
    elif (T is int64) or ((T is int) and (sizeof(int) == 8)):
      result = SInt64
    elif (
      (T is UInteger32Types) or
      ((T is uint) and (sizeof(uint) == 4))
    ):
      result = UInt32
    elif (T is uint64) or ((T is uint) and (sizeof(uint) == 8)):
      result = UInt64
    elif T is bool:
      result = PBool
    elif T is enum:
      result = PEnum
    elif T is LengthDelimitedTypes:
      result = Default
    elif T is float32:
      result = Float
    elif T is float64:
      result = Double
    else:
      {.fatal: "Told to use the default subtype for an unknown type.".}
  else:
    result = subtype

template setIndividualField[T](value: var T, stream: InputStreamHandle,
                               reader: untyped, subtypeArg: SubType) =
  when T is object:
    {.fatal: "Object made it to set individual field."}

  var subtype = getDefaultSubType[T](subtypeArg)
  value = stream.reader[:T](subtype)

template setLengthDelimitedField[T](value: var T, stream: InputStreamHandle) =
  when T is CastableLengthDelimitedTypes:
    value = cast[T](stream.readLengthDelimited())
  else:
    value = stream.readLengthDelimited().fromProtobuf[:T]()

template setField[T](value: var T, fieldKey: byte, stream: InputStreamHandle,
                     reader: untyped, subtypeArg: SubType) =
  when T is not LengthDelimitedTypes:
    var subtype = getDefaultSubtype[T](subtypeArg)

  when T is not object:
    when T is LengthDelimitedTypes:
      setLengthDelimitedField(value, stream)
    else:
      setIndividualField(value, stream, reader, subtype)
  else:
    #This iterative approach is extremely poor.
    var counter: int = 1
    enumInstanceSerializedFields(value, fieldName, fieldVar):
      if counter != fieldKey.fieldNumber:
        inc(counter)
      else:
        when fieldVar is SomeSignedInt:
          const
            hasPInt32 = T.hasCustomPragmaFixed(fieldName, pint32)
            hasSInt32 = T.hasCustomPragmaFixed(fieldName, sint32)
            hasPInt64 = T.hasCustomPragmaFixed(fieldName, pint64)
            hasSInt64 = T.hasCustomPragmaFixed(fieldName, sint64)
          when hasPInt32 or hasSInt32:
            when (fieldVar is not SomeSignedInt) or (sizeof(fieldVar) > 4):
              {.fatal: "Invalid application of the pint32/sint32 pragma to a non-number or number larger than 32 bits.".}
            subtype = if hasPInt32: SubType.PInt32 else: SubType.SInt32
          elif hasPInt64 or hasSInt64:
            when fieldVar is not SomeSignedInt:
              {.fatal: "Invalid application of the pint64/sint64 pragma to a non-number.".}
            subtype = if hasPInt64: SubType.PInt64 else: SubType.SInt64
          else:
            when sizeof(fieldVar) <= 4:
              {.fatal: fieldName & "'s encoding format was not specified. If you don't know whether to choose pint32 or sint32, use the sint32 pragma after the field name."}
            else:
              {.fatal: fieldName & "'s encoding format was not specified. If you don't know whether to choose pint64 or sint64, use the sint64 pragma after the field name."}

      when fieldVar is LengthDelimitedTypes:
          setLengthDelimitedField(fieldVar, stream)
      else:
        setIndividualField(fieldVar, stream, reader, subtype)

#SubType is passable to support individual values (e.g., `var x: int`).
proc decode*[T](reader: ProtobufReader, subtype: SubType = SubType.Default): T =
  while reader.stream.readable:
    let fieldKey = reader.stream.next().get()
    case fieldKey.wireType:
      #LengthDelimited doesn't get its own case due to how its return values are handled.
      #There's a special fieldKey check for it which means it doesn't matter what this code does.
      #That said, it still can't error our thinking it's an invalid type.
      of byte(VarInt), byte(LengthDelimited):
        result.setField(fieldKey, reader.stream, readVarInt, subtype)
      of byte(Fixed64):
        result.setField(fieldKey, reader.stream, readFixed64, subtype)
      of byte(StartGroup):
        raise newException(ProtobufLegacyError, "Handed legacy Protobuf message.")
      of byte(EndGroup):
        raise newException(ProtobufLegacyError, "Handed legacy Protobuf message.")
      of byte(Fixed32):
        result.setField(fieldKey, reader.stream, readFixed32, subtype)
      #If we just used ProtoWireType, we risk bound check errors on invalid messages.
      #This way, we can raise a derivation of ProtobufError.
      else:
        raise newException(ProtobufError, "Invalid field type sent.")
