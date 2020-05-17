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

#We don't cast this back to a ProtobufWireType despite exclusively comparing it against ProtobufWireTypes.
#This is so an invalid wire type doesn't trigger boundChecks.
template wireType(key: byte): byte =
  key and WIRE_TYPE_MASK

template fieldNumber(key: byte): byte =
  (key and FIELD_NUMBER_MASK) shr 3

proc eofSafeRead(stream: InputStream): byte =
  if not stream.readable():
    raise newException(ProtobufEOFError, "Couldn't read the next byte from this stream despite expecting one.")
  result = stream.read()

#Ideally, these would be in a table.
#That said, due to the context specific return type, which goes beyond the wire type, you need generics.
#As Generic types aren't concrete, they can't be used in a table.
proc readVarInt[B; E: VarIntWrapped](
  stream: InputStream,
  fieldVar: var B,
  encoding: E,
  key: byte
) {.raises: [Defect, IOError, ProtobufEOFError, ProtobufMessageError].} =
  type T = flatType(B)
  when E is not VarIntWrapped:
    {.fatal: "Tried to read a VarInt without a specified encoding. This should never happen.".}
  when sizeof(T) == 8:
    type
      S = int64
      U = uint64
  else:
    type
      S = int32
      U = uint32

  if key.wireType != byte(VarInt):
    raise newException(ProtobufMessageError, "Invalid wire type for a VarInt.")

  var
    value = U(0)
    offset = 0'i8
    next = VAR_INT_CONTINUATION_MASK
    preResult: T
  while (next and VAR_INT_CONTINUATION_MASK) != 0:
    next = stream.eofSafeRead()
    value += (next and U(VAR_INT_VALUE_MASK)) shl offset
    offset += 7

  #Unsigned, requiring no further work.
  when E is UIntWrapped:
    preResult = T(value)
  #Zig-zagged.
  elif E is SIntWrapped:
    preResult = T(S(value shr 1) xor -S(value and U(0b0000_0001)))
  else:
    #Not zig-zagged, yet negative.
    if offset == 70:
      #This should handle the lowest possible negative value.
      #The cast to a signed value causes it to error/wrap to the lowest value.
      #Said lowest value will be negative, multiplied by -1, and wrap again.
      #This behavior requires boundChecks to be turned off in order to not raise though.
      {.push boundChecks: off.}
      preResult = T(-S(value + 1))
      {.pop.}
    #Not zig-zagged, yet positive.
    else:
      preResult = T(value)

  #Box the result back up.
  box(fieldVar, preResult)

proc readFixed[B](
  stream: InputStream,
  fieldVar: var B,
  key: byte
) {.raises: [Defect, IOError, ProtobufEOFError, ProtobufMessageError].} =
  type T = flatType(B)
  when sizeof(T) == 8:
    type U = uint64
    if key.wireType != byte(Fixed64):
      raise newException(ProtobufMessageError, "Invalid wire type for a Fixed64.")
  else:
    type U = uint32
    if key.wireType != byte(Fixed32):
      raise newException(ProtobufMessageError, "Invalid wire type for a Fixed32.")

  var value = U(0)
  for offset in countup(0, (sizeof(T) - 1) * 8, 8):
    value += U(stream.eofSafeRead()) shl U(offset)
  box(fieldVar, cast[T](value))

#readValue requires readLengthDelimited function which requires readValue.
#This would risk infinite recursion, except nested sub-buffers have a limit of 255 bytes.
#Every sub-sub-buffer contributes to the length of the original buffer.
proc readValueInternal*[T](
  bytes: seq[byte],
  ty: typedesc[T]
): T {.raises: [
  Defect,
  IOError,
  ProtobufEOFError,
  ProtobufMessageError
].}

proc readLengthDelimited[B](
  stream: InputStream,
  fieldVar: var B,
  key: byte
) {.raises: [
  Defect,
  IOError,
  ProtobufEOFError,
  ProtobufMessageError
].} =
  if key.wireType != byte(LengthDelimited):
    raise newException(ProtobufMessageError, "Invalid wire type for a length delimited sequence/object.")

  var
    bytes = newSeq[byte](stream.eofSafeRead())
    preResult: flatType(B)
  for b in 0 ..< bytes.len:
    bytes[b] = stream.eofSafeRead()

  when preResult is not LengthDelimitedTypes:
    {.fatal: "Tried to read a Length Delimited value which we didn't recognize. This should never happen.".}
  elif preResult is CastableLengthDelimitedTypes:
    preResult = cast[type(preResult)](bytes)
  elif preResult is object:
    preResult = bytes.readValueInternal(type(preResult))
  else:
    bytes.fromProtobuf(preResult)

  box(fieldVar, preResult)

proc setField[T](
  value: var T,
  stream: InputStream,
  key: byte
) {.raises: [
  Defect,
  IOError,
  ProtobufEOFError,
  ProtobufMessageError
].} =
  if false:
    raise newException(ProtobufMessageError, "")

  when T is (ref or Option):
    {.fatal: "Ref or Option made it to setField. This should never happen.".}

  elif T is not object:
    when T is bool:
      stream.readVarInt(value, UInt(value), key)
    elif T is VarIntWrapped:
      stream.readVarInt(value, value, key)
    elif T is FixedWrapped:
      stream.readFixed(value, key)
    elif T is (PlatformDependentTypes or VarIntTypes or FixedTypes):
      {.fatal: "Reading into a number requires specifying both the amount of bits via the type, as well as the encoding format.".}
    else:
      stream.readLengthDelimited(value, key)

  else:
    #This iterative approach is extemely poor.
    var
      counter = 1'u8
      fieldNumber = key.fieldNumber
    if (fieldNumber == 0) or (uint(fieldNumber) > uint(totalSerializedFields(T))):
      raise newException(ProtobufMessageError, "Unknown field number specified: " & $fieldNumber)

    enumInstanceSerializedFields(value, fieldName, fieldVar):
      when fieldVar is PlatformDependentTypes:
        {.fatal: "Reading into a number requires specifying the amount of bits via the type.".}

      if counter != fieldNumber:
        inc(counter)
      else:
        #Only calculate the encoding VarInt.
        #In every other case, the type is enough.
        #We don't need to track the boolean type as literally every encoding will parse to the same true/false.
        when fieldVar is (VarIntWrapped or FixedWrapped):
          {.fatal: "Don't specify an encoding for a field via its type; use a pragma.".}

        var flattened: flatType(fieldVar)
        when flattened is bool:
          stream.readVarInt(flattened, UInt(flattened), key)
        elif flattened is SIntegerTypes:
          const
            hasPInt = T.hasCustomPragmaFixed(fieldName, pint)
            hasSInt = T.hasCustomPragmaFixed(fieldName, sint)
            hasFixed = T.hasCustomPragmaFixed(fieldName, fixed)
          when uint(hasPInt) + uint(hasSInt) + uint(hasFixed) != 1:
            {.fatal: "Couldn't write " & fieldName & "; either none or multiple encodings were specified.".}
          elif hasPInt:
            stream.readVarInt(flattened, PInt(flattened), key)
          elif hasSInt:
            stream.readVarInt(flattened, SInt(flattened), key)
          elif hasFixed:
            stream.readFixed(flattened, key)
          else:
            {.fatal: "Encoding pragma specified yet no enoding matched. This should never happen.".}

        elif flattened is UIntegerTypes:
          const
            hasUInt = T.hasCustomPragmaFixed(fieldName, puint)
            hasFixed = T.hasCustomPragmaFixed(fieldName, fixed)
          when uint(hasUInt) + uint(hasFixed) != 1:
            {.fatal: "Couldn't write " & fieldName & "; either none or multiple encodings were specified.".}
          elif hasUInt:
            stream.readVarInt(flattened, UInt(flattened), key)
          elif hasFixed:
            stream.readFixed(flattened, key)

        elif flattened is FixedTypes:
          const hasFixed = T.hasCustomPramgaFixed(fieldName, fixed)
          when not hasFixed:
            {.fatal: "Couldn't write " & fieldName & "; either none or multiple encodings were specified.".}
          stream.readFixed(flattened, key)

        else:
          stream.readLengthDelimited(flattened, key)

        box(fieldVar, flattened)
        break

proc readValueInternal*[T](
  bytes: seq[byte],
  ty: typedesc[T]
): T {.raises: [
  Defect,
  IOError,
  ProtobufEOFError,
  ProtobufMessageError
].} =
  if bytes.len == 0:
    return

  var stream = memoryInput(bytes)
  while stream.readable():
    result.setField(stream, stream.read())
  stream.close()

template readValue*[B](
  bytes: seq[byte],
  ty: typedesc[B]
): B =
  var tResult: B
  box(tResult, bytes.readValueInternal(flatType(B)))
  tResult
