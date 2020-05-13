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

#We don't cast this back to a ProtobufWireType despite exclusively comparing it against ProtobufWireTypes.
#This is so an invalid wire type doesn't trigger boundChecks.
template wireType(key: byte): byte =
  key and WIRE_TYPE_MASK

type
  ProtobufReadError* = object of ProtobufError
  ProtobufEOFError* = object of ProtobufReadError
  ProtobufDataRemainingError* = object of ProtobufReadError
  ProtobufMessageError* = object of ProtobufReadError

#Ideally, these would be in a table.
#That said, due to the context specific return type, which goes beyond the wire type, you need generics.
#As Generic types aren't concrete, they can't be used in a table.
proc readVarInt[T](
  stream: InputStreamHandle,
  subtype: VarIntSubType
): T {.raises: [Defect, IOError, ProtobufEOFError].} =
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

    if option.isNone():
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
): T {.raises: [
  Defect,
  IOError,
  ProtobufEOFError,
  ProtobufDataRemainingError,
  ProtobufMessageError
].}

template setLengthDelimitedField[T](
  value: var T,
  fieldKey: byte,
  stream: InputStreamHandle
) =
  mixin wireType, readLengthDelimited

  let wire = fieldKey.wireType
  if wire != byte(LengthDelimited):
    raise newException(ProtobufMessageError, "Invalid wire type for a length delimited sequence/object.")

  when T is CastableLengthDelimitedTypes:
    value = cast[T](stream.readLengthDelimited())
  elif T is (object or ref):
    value = stream.readLengthDelimited().readValue(type(T))
  else:
    value = stream.readLengthDelimited().fromProtobuf[:T]()

template setIndividualField[T](value: var T, fieldKey: byte,
                               stream: InputStreamHandle,
                               subtype: Option[VarIntSubType]) =
  when T is (object or ref):
    {.fatal: "Object made it to set individual field. This should never happen.".}

  mixin wireType
  let wire = fieldKey.wireType

  #VarInt and fixed integers.
  when T is VarIntTypes:
    case wire:
      of byte(VarInt):
        mixin isNone
        if subtype.isNone():
          raise newException(ProtobufMessageError, "Invalid subtype (Fixed/SFixed) for a VarInt.")
        value = stream.readVarInt[:T](subtype.get())
      of byte(Fixed64):
        if T is not Fixed64Types:
          raise newException(ProtobufMessageError, "Invalid wire type for an Fixed64.")
        value = stream.readFixed64[:T]()
      of byte(Fixed32):
        if T is not Fixed32Types:
          raise newException(ProtobufMessageError, "Invalid wire type for an Fixed32.")
        value = stream.readFixed32[:T]()
      else:
        raise newException(ProtobufMessageError, "Invalid wire type for an integer.")
  #Float64.
  elif T is Fixed64Types:
    if wire != byte(Fixed64):
      raise newException(ProtobufMessageError, "Invalid wire type for a float64.")
    value = stream.readFixed64[:T]()
  #Float32.
  elif T is Fixed32Types:
    if wire != byte(Fixed32):
      raise newException(ProtobufMessageError, "Invalid wire type for a float32.")
    value = stream.readFixed32[:T]()
  else:
    {.fatal: "Trying to read a type we don't understand. This should never happen.".}

proc setFields[T](
  value: var T,
  fieldKey: byte,
  stream: InputStreamHandle,
  subtypeArg: Option[VarIntSubType]
) {.raises: [
  Defect,
  IOError,
  ProtobufEOFError,
  ProtobufDataRemainingError,
  ProtobufMessageError
].} =
  #Fake raises to stop the raises from causing warnings about unused Exceptions.
  if false:
    raise newException(ProtobufMessageError, "")
  if false:
    raise newException(ProtobufDataRemainingError, "")

  when T is (object or ref):
    createActualTypeFromPotentialOption(value)

  when T is not (object or ref):
    when T is PlatformDependentTypes:
      {.fatal: "Reading into a number requires specifying the amount of bits via the type.".}
    elif T is LengthDelimitedTypes:
      setLengthDelimitedField(value, fieldKey, stream)
    else:
      setIndividualField(value, fieldKey, stream, subtypeArg)
  else:
    #This iterative approach is extremely poor.
    var
      counter = 1'u8
      fieldNumber = uint8((fieldKey and FIELD_NUMBER_MASK).int shr 3)
      alreadySet: set[uint8]
    if int(fieldNumber) > totalSerializedFields(AT):
      raise newException(ProtobufMessageError, "Unknown field number specified.")

    when getTypeImpl(AT).kind == nnkRefTy:
      if value.isNil:
        value = AT()

      macro hCP(field: static string, pragma: typed{nkSym}): untyped =
        for f in recordFields(newNimNode(nnkTypeDef).add(
          AT.getTypeImpl()[0],
          newNimNode(nnkEmpty),
          AT.getTypeImpl()[0].getImpl()[2][0]
        )):
          var thisField = f.name
          if thisField.kind == nnkAccQuoted: thisField = thisField[0]
          if eqIdent(thisField, field):
            return newLit(f.pragmas.findPragma(pragma) != nil)

      macro enumSerialized(body: untyped): untyped =
        result = quote do:
          for fieldName, fieldVar in fieldPairs(value[]):
            when not hCP(fieldName, dontSerialize):
              `body`

        var queue = @[result]
        while queue.len != 0:
          var next = queue.pop()
          for c in 0 ..< next.len:
            if eqIdent(next[c], ident("fieldName")):
              next[c] = result[0]
            elif eqIdent(next[c], ident("fieldVar")):
              next[c] = result[1]
            else:
              queue.add(next[c])
    else:
      macro enumSerialized(body: untyped): untyped =
        result = quote do:
          enumInstanceSerializedFields(value, fieldName, fieldVar):
            `body`

    enumSerialized():
      when fieldVar is not LengthDelimitedTypes:
        when fieldVar is PlatformDependentTypes:
          {.fatal: "Reading into a number requires specifying the amount of bits via the type.".}
        var subtype: Option[VarIntSubType]

      if counter != fieldNumber:
        inc(counter)
      else:
        #If we already read this field, raise.
        if alreadySet.contains(fieldNumber):
          raise newException(ProtobufMessageError, "Buffer had the same field twice.")
        alreadySet.incl(fieldNumber)

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

        var fakeField: type(fieldVar)
        when fakeField is LengthDelimitedTypes:
          setLengthDelimitedField(fakeField, fieldKey, stream)
        else:
          setIndividualField(fakeField, fieldKey, stream, subtype)
        when fieldVar is Option:
          fieldVar = some(fakeField)
        else:
          fieldVar = fakeField
        break

proc readValue*[T](
  bytes: seq[byte],
  ty: typedesc[T]
): T {.raises: [
  Defect,
  IOError,
  ProtobufEOFError,
  ProtobufDataRemainingError,
  ProtobufMessageError
].} =
  when T is not (object or ref):
    type AT = T
  else:
    var instance = T()
    createActualTypeFromPotentialOption(instance)

  when (AT is (PureSIntegerTypes or PureUIntegerTypes)) and (AT is not bool):
    {.fatal: "Reading into a number requires specifying the encoding via a SInt/PIntUInt/Fixed/SFixed wrapping call.".}

  var
    stream = memoryInput(bytes)
    next = stream.s.next()
    subtype: Option[VarIntSubType]
  when AT is (PIntWrapped32 or PIntWrapped64):
    subtype = some(PIntSubType)
  elif AT is (SIntWrapped32 or SIntWrapped64):
    subtype = some(SIntSubType)
  elif AT is (UIntWrapped32 or UIntWrapped64 or bool):
    subtype = some(UIntSubType)

  while next.isSome():
    when T is Option:
      var fakeValue: AT
      fakeValue.setFields(next.get(), stream, subtype)
      result = some(fakeValue)
    else:
      result.setFields(next.get(), stream, subtype)
    next = stream.s.next()
    when T is (Option or (not (object or ref))):
      break
  stream.s.close()

  when not defined(ProtobufAllowRemainingData):
    if next.isSome():
      raise newException(ProtobufDataRemainingError, "Buffer for a single value still had data remaining after it.")
