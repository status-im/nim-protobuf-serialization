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
#This was originally attempted with a raw template, and then a quote block.
#Nim modified the symbols and stopped resolution in functions which used this.
macro getSignedVariants(returnType: untyped): untyped =
  when sizeof(returnType) == 8:
    result = newNimNode(nnkConstSection).add(
      newNimNode(nnkConstDef).add(
        ident("S"),
        newNimNode(nnkEmpty),
        ident("int64"),
      ),
      newNimNode(nnkConstDef).add(
        ident("U"),
        newNimNode(nnkEmpty),
        ident("uint64"),
      )
    )
  else:
    result = newNimNode(nnkConstSection).add(
      newNimNode(nnkConstDef).add(
        ident("S"),
        newNimNode(nnkEmpty),
        ident("int32"),
      ),
      newNimNode(nnkConstDef).add(
        ident("U"),
        newNimNode(nnkEmpty),
        ident("uint32"),
      )
    )

template wireType(key: byte): byte =
  key and WIRE_TYPE_MASK

template fieldNumber(key: byte): int =
  (key and FIELD_NUMBER_MASK).int

#Ideally, these would be in a table.
#That said, due to the context specific return type, which goes beyond the wire type, you need generics.
#As Generic types aren't concrete, they can't be used in a table.
proc readVarInt[T](stream: InputStreamHandle, subtype: SubType): T =
  getSignedVariants(T)

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
  if subtype == SInt:
    if (value and U(0b0000_0001)) == 1:
      result = T(-S(value shr 1) - 1)
    else:
      result = T(value shr 1)
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
  getSignedVariants(T)

  var
    value = S(0)
    next: Option[byte]
  for offset in countup(0, 56, 8):
    next = stream.next()
    if next.isNone():
      raise newException(ProtobufEOFError, "Couldn't read a fixed 64-bit number from this stream.")
    value += S(next.get()) shl S(offset)
  result = T(value)

proc readLengthDelimited(stream: InputStreamHandle): seq[byte] =
  if not stream.readable():
    raise newException(ProtobufEOFError, "Couldn't read a length delimited sequence from this stream.")

  result = newSeq[byte](stream.next().get())
  for _ in 0 ..< result.len:
    if not stream.readable():
      raise newException(ProtobufEOFError, "Couldn't read a length delimited sequence from this stream.")
    result.add(stream.next().get())

proc readFixed32[T](stream: InputStreamHandle): T =
  getSignedVariants(T)

  var
    value = S(0)
    next: Option[byte]
  for offset in countup(0, 24, 8):
    next = stream.next()
    if next.isNone():
      raise newException(ProtobufEOFError, "Couldn't read a fixed 32-bit number from this stream.")
    value += S(next.get()) shl S(offset)
  result = T(value)

#The only reason this is used is so variables, as in raw ints, can be serialized/parsed.
#They should really have pragmas attached, removing the need for this.
proc getDefaultSubType[T](subtype: SubType): SubType =
  if subtype == Default:
    when T is SomeSignedInt:
      result = SInt
    when T is SomeUnsignedInt:
      result = UInt
    elif T is bool:
      result = UInt
    elif T is enum:
      result = SInt
    else:
      {.fatal: "Told to use the default subtype for an unknown type.".}
  else:
    result = subtype

template setIndividualField[T](value: var T, stream: InputStreamHandle,
                               reader: untyped, subtypeArg: SubType) =
  when T is object:
    {.fatal: "Object made it to set individual field."}

  when reader is type(readVarInt):
    value = stream.reader[:T](getDefaultSubType[T](subtypeArg))
  else:
    value = stream.reader[:T]()

template setLengthDelimitedField[T](value: var T, stream: InputStreamHandle) =
  when T is CastableLengthDelimitedTypes:
    value = cast[T](stream.readLengthDelimited())
  else:
    value = stream.readLengthDelimited().fromProtobuf[:T]()

template setField[T](value: var T, fieldKey: byte, stream: InputStreamHandle,
                     reader: untyped, subtypeArg: SubType) =

  var subtype = subtypeArg
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
        #Only calculate the subtype for VarInt.
        #In every other case, the variable type is enough.
        #Writing does have further specification rules, but those aren't needed here.
        when reader is type(readVarInt):
          when fieldVar is IntegerTypes:
            const
              hasPInt = T.hasCustomPragmaFixed(fieldName, pint)
              hasSInt = T.hasCustomPragmaFixed(fieldName, sint)
            when (hasPInt or hasSInt) and (fieldVar is not SIntegerTypes):
              {.fatal: "Invalid application of the pint/sint pragma to an unsigned number.".}
            elif hasPInt and hasSInt:
              {.fatal: "Multiple encoding specification pragmas attached to a single field.".}
            elif hasPInt:
              subtype = SubType.PInt
            elif hasSInt:
              subtype = SubType.SInt
            elif fieldVar is UIntegerTypes:
              subtype = SubType.UInts
            else:
              {.fatal: fieldName & "'s encoding format was not specified. If you don't know whether to choose pint or sint, use the sint pragma after the field name.".}

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
