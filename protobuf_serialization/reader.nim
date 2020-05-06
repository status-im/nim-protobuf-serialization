import options

import stew/shims/macros
import faststreams
import serialization

import types

const
  FIELD_NUMBER_MASK: byte = 0b1111_1000
  WIRE_TYPE_MASK: byte = 0b0000_0111

type
  ProtobufEOFError* = object of ProtobufError
  ProtobufLegacyError* = object of ProtobufError

#Ideally, these would be in a table.
#That said, due to the context specific return type, which goes beyond the wire type, you need generics.
#As Generic types aren't concrete, they can't be used in a table.
proc readVarInt[T](stream: InputStreamHandle, subtype: VarIntSubType): T =
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
    offset: int8 = 0
    next = VAR_INT_CONTINUATION_MASK
  while (next and VAR_INT_CONTINUATION_MASK) != 0:
    let option = stream.s.next()

    if option.isNone:
      raise newException(ProtobufEOFError, "Couldn't read a VarInt from this stream.")

    next = option.get()
    value += (next and U(VAR_INT_VALUE_MASK)) shl offset
    offset += 7

  #Zig-zagged.
  if subtype == SInt:
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

proc readFixed64[T](stream: InputStreamHandle): T =
  when sizeof(result) == 8:
    type
      S = int64
      U = uint64
  else:
    type
      S = int32
      U = uint32

  var
    value = S(0)
    next: Option[byte]
  for offset in countup(0, 56, 8):
    next = stream.s.next()
    if next.isNone():
      raise newException(ProtobufEOFError, "Couldn't read a fixed 64-bit number from this stream.")
    value += S(next.get()) shl S(offset)
  result = T(value)

proc readLengthDelimited(stream: InputStreamHandle): seq[byte] =
  if not stream.readable():
    raise newException(ProtobufEOFError, "Couldn't read a length delimited sequence from this stream.")

  result = newSeq[byte](stream.s.next().get())
  for _ in 0 ..< result.len:
    if not stream.readable():
      raise newException(ProtobufEOFError, "Couldn't read a length delimited sequence from this stream.")
    result.add(stream.s.next().get())

proc readFixed32[T](stream: InputStreamHandle): T =
  when sizeof(result) == 8:
    type
      S = int64
      U = uint64
  else:
    type
      S = int32
      U = uint32

  var
    value = S(0)
    next: Option[byte]
  for offset in countup(0, 24, 8):
    next = stream.s.next()
    if next.isNone():
      raise newException(ProtobufEOFError, "Couldn't read a fixed 32-bit number from this stream.")
    value += S(next.get()) shl S(offset)
  result = T(value)

#The only reason this is used is so variables, as in raw ints, can be serialized/parsed.
#They should really have pragmas attached, removing the need for this.
proc getDefaultSubType[T](subtype: VarIntSubType): VarIntSubType =
  if subtype == Default:
    when T is (SIntegerTypes or enum):
      result = SInt
    elif T is UIntegerTypes:
      result = PInt
    else:
      {.fatal: "Told to use the default subtype for an unknown type: " & $T.}
  else:
    result = subtype

template setIndividualField[T](value: var T, fieldKey: byte,
                               stream: InputStreamHandle,
                               subtypeArg: VarIntSubType) =
  when T is object:
    {.fatal: "Object made it to set individual field."}

  #We don't cast this back to a ProtoWireType despite exclusively comparing it against ProtoWireTypes.
  #This is so an invalid wire type doesn't trigger boundChecks.
  var wire = fieldKey and WIRE_TYPE_MASK

  #VarInt and fixed integers.
  when T is VarIntTypes:
    case wire:
      of byte(VarInt):
        value = stream.readVarInt[:T](getDefaultSubType[T](subtypeArg))
      of byte(Fixed64):
        value = stream.readFixed64[:T]()
      of byte(Fixed32):
        value = stream.readFixed32[:T]()
      else:
        raise newException(ProtobufError, "Invalid wire type for an integer: " & $wire)
  #Float64.
  elif T is Fixed64Types:
    if wire != byte(Fixed64):
      raise newException(ProtobufError, "Invalid wire type for a float64: " & $wire)
    value = stream.readFixed64[:T]()
  #Arrays and objects.
  elif T is LengthDelimitedTypes:
    if wire != byte(LengthDelimited):
      raise newException(ProtobufError, "Invalid wire type for a Length Delimited sequence/object: " & $wire)
    stream.readLengthDelimitedTypes[:T]()
  #Float32.
  elif T is Fixed32Types:
    if wire != byte(Fixed32):
      raise newException(ProtobufError, "Invalid wire type for a float32: " & $wire)
    value = stream.readFixed32[:T]()
  else:
    {.fatal: "Handling unknown type.".}

template setLengthDelimitedField[T](value: var T, stream: InputStreamHandle) =
  when T is CastableLengthDelimitedTypes:
    value = cast[T](stream.readLengthDelimited())
  else:
    value = stream.readLengthDelimited().fromProtobuf[:T]()

template setField[T](value: var T, fieldKey: byte, stream: InputStreamHandle,
                     subtypeArg: VarIntSubType) =

  var subtype = subtypeArg
  when T is not object:
    when T is LengthDelimitedTypes:
      setLengthDelimitedField(value, stream)
    else:
      setIndividualField(value, fieldKey, stream, subtype)
  else:
    #This iterative approach is extremely poor.
    var counter: int = 1
    enumInstanceSerializedFields(value, fieldName, fieldVar):
      if counter != (fieldKey and FIELD_NUMBER_MASK).int:
        inc(counter)
      else:
        #Only calculate the subtype for VarInt.
        #In every other case, the variable type is enough.
        #Writing does have further specification rules, but those aren't needed here.
        when T is VarIntTypes:
          if fiedKey.wireType == VarInt:
            const
              hasPInt = T.hasCustomPragmaFixed(fieldName, pint)
              hasSInt = T.hasCustomPragmaFixed(fieldName, sint)
            when (hasPInt or hasSInt) and (fieldVar is not SIntegerTypes):
              {.fatal: "Invalid application of the pint/sint pragma to an unsigned number.".}
            elif hasPInt and hasSInt:
              {.fatal: "Multiple encoding specification pragmas attached to a single field.".}
            elif hasPInt:
              subtype = PInt
            elif hasSInt:
              subtype = SInt
            else:
              {.fatal: fieldName & "'s encoding format was not specified. If you don't know whether to choose pint or sint, use the sint pragma after the field name.".}

        when fieldVar is LengthDelimitedTypes:
            setLengthDelimitedField(fieldVar, stream)
        else:
          setIndividualField(fieldVar, fieldKey, stream, subtype)

#SubType is passable to support individual values (e.g., `var x: int`).
proc readValue*[T](bytes: seq[byte], ty: typedesc[T], subtype: VarIntSubType = Default): T =
  var stream: InputStreamHandle = memoryInput(bytes)
  while stream.s.readable:
    result.setField(stream.s.next().get(), stream, subtype)
  stream.s.close()
