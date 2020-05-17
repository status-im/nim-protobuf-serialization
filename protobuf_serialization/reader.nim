#Parses the Protobuf binary wire protocol into the specified type.

import options

import stew/shims/macros
import faststreams/inputs
import serialization

import internal
import types

const
  FIELD_NUMBER_MASK: byte = 0b1111_1000
  WIRE_TYPE_MASK: byte = 0b0000_0111

type
  ProtobufReadError* = object of ProtobufError
  ProtobufEOFError* = object of ProtobufReadError
  ProtobufMessageError* = object of ProtobufReadError

  VarIntSubType = enum
    PIntSubType,
    SIntSubType,
    UIntSubType

  Fixed64Types = int64 or uint64 or float64 or FixedWrapped64 or SFixedWrapped64
  Fixed32Types = int32 or uint32 or float32 or FixedWrapped32 or SFixedWrapped32

#We don't cast this back to a ProtobufWireType despite exclusively comparing it against ProtobufWireTypes.
#This is so an invalid wire type doesn't trigger boundChecks.
template wireType(key: byte): byte =
  key and WIRE_TYPE_MASK

template fieldNumber(key: byte): byte =
  (key and FIELD_NUMBER_MASK) shr 3

template wireCheck(typeclass: untyped, expected: ProtobufWireType) =
  if T is not typeclass:
    raise newException(ProtobufMessageError, "Invalid wire type. Expected " & $expected & ".")

macro getActualType(option: typed): untyped =
  var inst = getTypeInst(option)
  if (inst.kind == nnkSym) and (inst.strVal == "AT"):
    raise newException(Defect, "Option[Option[T]] declared. This is not a valid serializable object. For more info, see https://github.com/kayabaNerve/nim-protobuf-serialization/issues/14.")

  if (inst.kind == nnkBracketExpr) and (inst[0].kind == nnkSym) and (inst[0].strVal == "Option"):
    result = inst[1]
  else:
    result = inst

#Ideally, these would be in a table.
#That said, due to the context specific return type, which goes beyond the wire type, you need generics.
#As Generic types aren't concrete, they can't be used in a table.
proc readVarInt[T](
  stream: InputStream,
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
    if not stream.readable():
      raise newException(ProtobufEOFError, "Couldn't read a VarInt from this stream.")

    next = stream.read()
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
    result = T(-S(value + 1))
    {.pop.}
  #Not zig-zagged, yet positive.
  else:
    result = T(value)

proc readFixed64[T](
  stream: InputStream
): T {.raises: [Defect, IOError, ProtobufEOFError].} =
  type U = uint64
  var value = U(0)
  for offset in countup(0, 56, 8):
    if not stream.readable():
      raise newException(ProtobufEOFError, "Couldn't read a fixed 64-bit number from this stream.")
    value += U(stream.read()) shl U(offset)
  result = cast[T](value)

proc readFixed32[T](
  stream: InputStream
): T {.raises: [Defect, IOError, ProtobufEOFError].} =
  type U = uint64
  var
    value = U(0)
  for offset in countup(0, 24, 8):
    if not stream.readable():
      raise newException(ProtobufEOFError, "Couldn't read a fixed 32-bit number from this stream.")
    value += U(stream.read()) shl U(offset)
  result = cast[T](value)

proc readLengthDelimited(
  stream: InputStream
): seq[byte] {.raises: [Defect, IOError, ProtobufEOFError].} =
  if not stream.readable():
    raise newException(ProtobufEOFError, "Couldn't read a length delimited sequence from this stream.")

  result = newSeq[byte](stream.read())
  for b in 0 ..< result.len:
    if not stream.readable():
      raise newException(ProtobufEOFError, "Couldn't read a length delimited sequence from this stream.")
    result[b] = stream.read()

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
  ProtobufMessageError
].}

proc setLengthDelimitedField[S](
  sourceValue: S,
  fieldKey: byte,
  stream: InputStream
): S {.raises: [
  Defect,
  IOError,
  ProtobufEOFError,
  ProtobufMessageError
].} =
  mixin wireType, readLengthDelimited

  let wire = fieldKey.wireType
  if wire != byte(LengthDelimited):
    raise newException(ProtobufMessageError, "Invalid wire type for a length delimited sequence/object.")

  var preResult: getActualType(sourceValue)
  when preResult is CastableLengthDelimitedTypes:
    preResult = cast[type(preResult)](stream.readLengthDelimited())
  elif preResult is (object or ref):
    when sourceValue is Option:
      preResult = stream.readLengthDelimited().readValue(S).get()
    else:
      preResult = stream.readLengthDelimited().readValue(S)
  else:
    stream.readLengthDelimited().fromProtobuf(preResult)

  when S is Option:
    result = some(preResult)
  else:
    result = preResult

proc setIndividualField[T](
  fieldKey: byte,
  stream: InputStream,
  subtype: Option[VarIntSubType]
): T =
  when T is (object or ref):
    {.fatal: "Object made it to set individual field. This should never happen.".}

  mixin wireType
  let wire = fieldKey.wireType

  case wire:
    of byte(VarInt):
      mixin isNone
      if subtype.isNone():
        raise newException(ProtobufMessageError, "Invalid subtype (Fixed/SFixed) for a VarInt.")
      result = stream.readVarInt[:T](subtype.get())
    of byte(Fixed64):
      wireCheck(Fixed64Types, Fixed64)
      result = stream.readFixed64[:T]()
    of byte(Fixed32):
      wireCheck(Fixed32Types, Fixed32)
      result = stream.readFixed32[:T]()
    else:
      raise newException(ProtobufMessageError, "Invalid wire type for an integer.")

proc setFields[T](
  value: var T,
  fieldKey: byte,
  stream: InputStream,
  subtypeArg: Option[VarIntSubType]
) {.raises: [
  Defect,
  IOError,
  ProtobufEOFError,
  ProtobufMessageError
].} =
  if false:
    raise newException(ProtobufMessageError, "")

  type AT = getActualType(value)
  var fakeValue: AT
  when fakeValue is not (object or ref):
    when fakeValue is PlatformDependentTypes:
      {.fatal: "Reading into a number requires specifying the amount of bits via the type.".}
    elif fakeValue is LengthDelimitedTypes:
      value = setLengthDelimitedField(value, fieldKey, stream)
    else:
      when T is Option:
        value = some(setIndividualField[AT](fieldKey, stream, subtypeArg))
      else:
        value = setIndividualField[T](fieldKey, stream, subtypeArg)
  else:
    fakeValue = AT()

    #This iterative approach is extremely poor.
    var
      counter = 1'u8
      fieldNumber = fieldKey.fieldNumber
    if (fieldNumber == 0) or (int(fieldNumber) > totalSerializedFields(AT)):
      raise newException(ProtobufMessageError, "Unknown field number specified: " & $fieldNumber)

    when fakeValue is ref:
      when T is Option:
        var valueCopy = AT()
        if value.isSome():
          valueCopy = value.get()
      else:
        var valueCopy = value
        if valueCopy.isNil:
          valueCopy = AT()
      when T is Option:
        value = some(valueCopy)
      else:
        value = valueCopy

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
          for fieldName, fieldVar in fieldPairs(fakeValue[]):
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
        quote do:
          enumInstanceSerializedFields(fakeValue, fieldName, fieldVar):
            `body`

    enumSerialized():
      when fieldVar is PlatformDependentTypes:
        {.fatal: "Reading into a number requires specifying the amount of bits via the type.".}
      if counter != fieldNumber:
        inc(counter)
      else:
        var fakeField: getActualType(fieldVar)

        #Only calculate the subtype for VarInt.
        #In every other case, the type is enough.
        #Writing does have further specification rules, but those aren't needed here.
        #We don't need to track the boolean type as literally every encoding will parse to the same true/false.
        when fakeField is not LengthDelimitedTypes:
          var subtype: Option[VarIntSubType]
        when fakeField is bool:
          subtype = some(UIntSubType)
        elif fakeField is VarIntTypes:
          mixin hasCustomPragmaFixed, wireType
          if fieldKey.wireType == byte(VarInt):
            const
              hasPInt = AT.hasCustomPragmaFixed(fieldName, pint)
              hasPUInt = AT.hasCustomPragmaFixed(fieldName, puint)
              hasSInt = AT.hasCustomPragmaFixed(fieldName, sint)
            when (uint(hasPInt) + uint(hasPUInt) + uint(hasSInt)) != 1:
              {.fatal: fieldName & " either had multiple encoding formats or none specified.".}
            elif (hasPInt or hasSInt) and (fakeField is not SIntegerTypes):
              {.fatal: "Invalid application of the pint/sint pragma to an unsigned number.".}
            elif hasPUInt and (fakeField is not UIntegerTypes):
              {.fatal: "Invalid application of the puint pragma to a signed number.".}
            elif hasPInt:
              subtype = some(PIntSubType)
            elif hasSInt:
              subtype = some(SIntSubType)
            elif hasPUInt:
              subtype = some(UIntSubType)

        when fakeField is LengthDelimitedTypes:
          when fieldVar is Option:
            when type(setLengthDelimitedField(fieldVar, fieldKey, stream)) is Option:
              fieldVar = setLengthDelimitedField(fieldVar, fieldKey, stream)
            else:
              fieldVar = some(setLengthDelimitedField(fieldVar, fieldKey, stream))
          else:
            fieldVar = setLengthDelimitedField(fieldVar, fieldKey, stream)
        else:
          when fieldVar is Option:
            fakeField = setIndividualField[type(fakeField)](fieldKey, stream, subtype)
            fieldVar = some(fakeField)
          else:
            fieldVar = setIndividualField[type(fakeField)](fieldKey, stream, subtype)

        macro mergeField(mergeInto: untyped, toMerge: untyped): untyped =
          result = newNimNode(nnkAsgn).add(
            newNimNode(nnkDotExpr).add(
              mergeInto,
              ident(fieldName)
            ),
            toMerge
          )
        when T is Option:
          if value.isNone():
            when AT is (object or ref):
              value = some(AT())
          var valueCopy = value.get()
        else:
          var valueCopy = value
        mergeField(valueCopy, fieldVar)
        when T is Option:
          value = some(valueCopy)
        else:
          value = valueCopy
        break

proc readValue*[T](
  bytes: seq[byte],
  ty: typedesc[T]
): T {.raises: [
  Defect,
  IOError,
  ProtobufEOFError,
  ProtobufMessageError
].} =
  when T is not (object or ref):
    type AT = T
  else:
    type AT = getActualType(T())

  when (AT is (PureSIntegerTypes or PureUIntegerTypes)) and (AT is not bool):
    {.fatal: "Reading into a number requires specifying the encoding via a SInt/PIntUInt/Fixed/SFixed wrapping call.".}

  if bytes.len == 0:
    when T is ref:
      return T()
    else:
      return

  var
    stream = memoryInput(bytes)
    subtype: Option[VarIntSubType]
  when AT is (PIntWrapped32 or PIntWrapped64):
    subtype = some(PIntSubType)
  elif AT is (SIntWrapped32 or SIntWrapped64):
    subtype = some(SIntSubType)
  elif AT is (UIntWrapped32 or UIntWrapped64 or bool):
    subtype = some(UIntSubType)

  while stream.readable():
    setFields(result, stream.read(), stream, subtype)
  stream.close()
