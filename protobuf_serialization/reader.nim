#Parses the Protobuf binary wire protocol into the specified type.

import options

import stew/shims/macros
import faststreams/input_stream
import serialization

import internal
import types

const
  FIELD_NUMBER_MASK: byte = 0b1111_1000
  WIRE_TYPE_MASK: byte = 0b0000_0111

#We don't cast this back to a ProtoWireType despite exclusively comparing it against ProtoWireTypes.
#This is so an invalid wire type doesn't trigger boundChecks.
template wireType(key: byte): byte =
  key and WIRE_TYPE_MASK

type
  ProtobufEOFError* = object of ProtobufError
  ProtobufLegacyError* = object of ProtobufError
  ProtobufMessageError* = object of ProtobufError

#Ideally, these would be in a table.
#That said, due to the context specific return type, which goes beyond the wire type, you need generics.
#As Generic types aren't concrete, they can't be used in a table.
proc readVarInt[T](
  stream: InputStreamHandle,
  subtype: VarIntSubType
): T {.raises: [Defect, IOError, ProtobufEOFError, ProtobufMessageError].} =
  if subtype in {FixedSubType, SFixedSubType}:
    raise newException(ProtobufMessageError, "VarInt message used for a Fixed data type.")

  when sizeof(result) == 8:
    type
      S = int64
      U = uint64
  else:
    type
      S = int32
      U = uint32

  var
    value = U(0)
    offset = 0'i8
    next = VAR_INT_CONTINUATION_MASK
  while (next and VAR_INT_CONTINUATION_MASK) != 0:
    let option = stream.s.next()

    if option.isNone:
      raise newException(ProtobufEOFError, "Couldn't read a VarInt from this stream.")

    next = option.get()
    value += (next and U(VAR_INT_VALUE_MASK)) shl offset
    offset += 7

  #Unsigned, requiring no further work.
  if subtype == UIntSubType:
    result = T(value)
  #Zig-zagged.
  elif subtype == SIntSubType:
    result = T(S(value shr 1) xor -S(value and U(0b0000_0001)))
  #Not zig-zagged, yet negative.
  elif offset == 70:
    #This should handle the lowest possible negative value.
    #The cast to a signed value causes it to error/wrap to the lowest value.
    #Said lowest value will be negative, multiplied by -1, and wrap again.
    #This behavior requires boundChecks to be turned off in order to not raise though.
    {.push boundChecks: off.}
    result = T(-S(value))
    {.pop.}
  #Not zig-zagged, yet positive.
  else:
    result = T(value)

proc readFixed64[T](
  stream: InputStreamHandle
): T {.raises: [Defect, IOError, ProtobufEOFError].} =
  type U = uint64
  var
    value = U(0)
    next: Option[byte]
  for offset in countup(0, 56, 8):
    next = stream.s.next()
    if next.isNone():
      raise newException(ProtobufEOFError, "Couldn't read a fixed 64-bit number from this stream.")
    value += U(next.get()) shl U(offset)
  result = cast[T](value)

proc readFixed32[T](
  stream: InputStreamHandle
): T {.raises: [Defect, IOError, ProtobufEOFError].} =
  type U = uint64
  var
    value = U(0)
    next: Option[byte]
  for offset in countup(0, 24, 8):
    next = stream.s.next()
    if next.isNone():
      raise newException(ProtobufEOFError, "Couldn't read a fixed 32-bit number from this stream.")
    value += U(next.get()) shl U(offset)
  result = cast[T](value)

#This had name resolution errors when placed elsewhere.
proc readLengthDelimited(
  stream: InputStreamHandle
): seq[byte] {.raises: [Defect, IOError, ProtobufEOFError].} =
  if not stream.s.readable():
    raise newException(ProtobufEOFError, "Couldn't read a length delimited sequence from this stream.")

  result = newSeq[byte](stream.s.next().get())
  for b in 0 ..< result.len:
    if not stream.s.readable():
      raise newException(ProtobufEOFError, "Couldn't read a length delimited sequence from this stream.")
    result[b] = stream.s.next().get()

#readValue requires this function which requires readValue.
#It should be noted this is recursive, and therefore can theoretically risk a stack overflow.
#As long as circular types are detected at compile time, this shouldn't be a problem.
proc readValue*[T](
  bytes: seq[byte],
  ty: typedesc[T]
): T {.raises: [Defect, IOError, ProtobufEOFError, ProtobufMessageError].}

template setLengthDelimitedField[T](
  value: var T,
  fieldKey: byte,
  stream: InputStreamHandle
) =
  mixin wireType, readLengthDelimited

  let wire = fieldKey.wireType
  if wire != byte(LengthDelimited):
    raise newException(ProtobufMessageError, "Invalid wire type for a length delimited sequence/object: " & $wire)

  when T is CastableLengthDelimitedTypes:
    value = cast[T](stream.readLengthDelimited())
  elif T is object:
    value = stream.readLengthDelimited().readValue(type(T))
  else:
    value = stream.readLengthDelimited().fromProtobuf[:T]()

template setIndividualField[T](value: var T, fieldKey: byte,
                               stream: InputStreamHandle,
                               subtypeArg: Option[VarIntSubType]) =
  when T is object:
    {.fatal: "Object made it to set individual field. This should never happen.".}

  mixin wireType
  let wire = fieldKey.wireType

  #VarInt and fixed integers.
  when T is VarIntTypes:
    case wire:
      of byte(VarInt):
        value = stream.readVarInt[:T](subtypeArg.get())
      of byte(Fixed64):
        value = stream.readFixed64[:T]()
      of byte(Fixed32):
        value = stream.readFixed32[:T]()
      else:
        raise newException(ProtobufMessageError, "Invalid wire type for an integer: " & $wire)
  #Float64.
  elif T is Fixed64Types:
    if wire != byte(Fixed64):
      raise newException(ProtobufMessageError, "Invalid wire type for a float64: " & $wire)
    value = stream.readFixed64[:T]()
  #Float32.
  elif T is Fixed32Types:
    if wire != byte(Fixed32):
      raise newException(ProtobufMessageError, "Invalid wire type for a float32: " & $wire)
    value = stream.readFixed32[:T]()

template setFields[T](
  value: var T,
  fieldKey: byte,
  stream: InputStreamHandle,
  subtypeArg: Option[VarIntSubType]
) =
  when T is not object:
    when T is LengthDelimitedTypes:
      setLengthDelimitedField(value, fieldKey, stream)
    else:
      setIndividualField(value, fieldKey, stream, subtypeArg)
  else:
    #This iterative approach is extremely poor.
    var counter = 1
    enumInstanceSerializedFields(value, fieldName, fieldVar):
      when fieldVar is not LengthDelimitedTypes:
        var subtype: Option[VarIntSubType]

      if counter != ((fieldKey and FIELD_NUMBER_MASK).int shr 3):
        inc(counter)
      else:
        #Only calculate the subtype for VarInt.
        #In every other case, the type is enough.
        #Writing does have further specification rules, but those aren't needed here.
        #We don't need to track the boolean type as literally every encoding will parse to the same true/false.
        when fieldVar is bool:
          subtype = some(UIntSubType)
        elif (fieldVar is VarIntTypes) and (fieldVar is not bool):
          mixin hasCustomPragmaFixed, wireType
          if fieldKey.wireType == byte(VarInt):
            const
              hasPInt = T.hasCustomPragmaFixed(fieldName, pint)
              hasPUInt = T.hasCustomPragmaFixed(fieldName, puint)
              hasSInt = T.hasCustomPragmaFixed(fieldName, sint)
            when (uint(hasPInt) + uint(hasPUInt) + uint(hasSInt)) != 1:
              {.fatal: fieldName & " either had multiple encoding formats or none specified.".}
            elif (hasPInt or hasSInt) and (fieldVar is not SIntegerTypes):
              {.fatal: "Invalid application of the pint/sint pragma to an unsigned number.".}
            elif hasPUInt and (fieldVar is not UIntegerTypes):
              {.fatal: "Invalid application of the puint pragma to a signed number.".}
            elif hasPInt:
              subtype = some(PIntSubType)
            elif hasSInt:
              subtype = some(SIntSubType)
            elif hasPUInt:
              subtype = some(UIntSubType)

        when fieldVar is LengthDelimitedTypes:
          setLengthDelimitedField(fieldVar, fieldKey, stream)
          break
        else:
          setIndividualField(fieldVar, fieldKey, stream, subtype)
          break

proc readValue*[T](
  bytes: seq[byte],
  ty: typedesc[T]
): T {.raises: [Defect, IOError, ProtobufEOFError, ProtobufMessageError].} =
  when (T is (PureSIntegerTypes or PureUIntegerTypes)) and (T is not bool):
    {.fatal: "Reading into a number requires specifying the encoding via a SInt/PIntUInt/Fixed/SFixed wrapping call.".}

  var
    stream = memoryInput(bytes)
    next = stream.s.next()
    subtype: Option[VarIntSubType]
  when T is (PIntWrapped32 or PIntWrapped64):
    subtype = some(PIntSubType)
  elif T is (SIntWrapped32 or SIntWrapped64):
    subtype = some(SIntSubType)
  elif T is (UIntWrapped32 or UIntWrapped64 or bool):
    subtype = some(UIntSubType)

  while next.isSome():
    result.setFields(next.get(), stream, subtype)
    next = stream.s.next()
    when T is not object:
      return
  stream.s.close()
