#Parses the Protobuf binary wire protocol into the specified type.

import options

import stew/shims/macros
import faststreams/inputs
import serialization

import internal
import types

const WIRE_TYPE_MASK = 0b0000_0111'u32

func handleReadException*(
  reader: ProtobufReader,
  Record: type,
  fieldName: string,
  field: auto,
  err: ref CatchableError
) {.inline.} =
  raise err

proc eofSafeRead(stream: InputStream): byte =
  if not stream.readable():
    raise newException(ProtobufEOFError, "Couldn't read the next byte from this stream despite expecting one.")
  result = stream.read()

proc readProtobufKey*(
  stream: InputStream
): ProtobufKey =
  let
    varint = stream.decodeVarInt(uint32, UInt(uint32))
    wire = byte(varint and WIRE_TYPE_MASK)
  if (wire < byte(low(ProtobufWireType))) or (byte(high(ProtobufWireType)) < wire):
    raise newException(ProtobufMessageError, "Protobuf key had an invalid wire type.")
  result.wire = ProtobufWireType(wire)
  result.number = varint shr 3

proc readVarInt[B; E](
  stream: InputStream,
  fieldVar: var B,
  encoding: E,
  key: ProtobufKey
) =
  when E is not VarIntWrapped:
    {.fatal: "Tried to read a VarInt without a specified encoding. This should never happen.".}

  if key.wire != VarInt:
    raise newException(ProtobufMessageError, "Invalid wire type for a VarInt.")

  #Box the result back up.
  box(fieldVar, stream.decodeVarInt(flatType(B), type(E)))

proc readFixed[B](stream: InputStream, fieldVar: var B, key: ProtobufKey) =
  type T = flatType(B)
  when sizeof(T) == 8:
    type U = uint64
    if key.wire != Fixed64:
      raise newException(ProtobufMessageError, "Invalid wire type for a Fixed64.")
  else:
    type U = uint32
    if key.wire != Fixed32:
      raise newException(ProtobufMessageError, "Invalid wire type for a Fixed32.")

  var value = U(0)
  for offset in countup(0, (sizeof(T) - 1) * 8, 8):
    value += U(stream.eofSafeRead()) shl U(offset)
  box(fieldVar, cast[T](value))

include stdlib_readers

proc readValueInternal[T](stream: InputStream, ty: typedesc[T]): T

proc readLengthDelimited[B](
  stream: InputStream,
  fieldVar: var B,
  key: ProtobufKey
) =
  if key.wire != LengthDelimited:
    raise newException(ProtobufMessageError, "Invalid wire type for a length delimited sequence/object.")

  var
    #We need to specify a bit quantity for decode to be satisfied.
    #int64 won't work on int32 systems, as this eventually needs to be casted to int.
    #We could just use the proper int size for the system.
    #That said, a 2 GB buffer limit isn't a horrible idea from a security perspective.
    #If anyone has a valid reason for one, let me know.

    #Uses PInt to ensure 31-bits are used, not 32-bits.
    len = stream.decodeVarInt(int, PInt(int32))
    preResult: B
  if len < 0:
    raise newException(ProtobufMessageError, "Length delimited buffer contained more than 2 GB of data.")

  if not stream.readable(len):
    raise newException(ProtobufEOFError, "Couldn't read the length delimited buffer from this stream despite expecting one.")

  stream.withReadableRange(len, substream):
    when preResult is not LengthDelimitedTypes:
      {.fatal: "Tried to read a Length Delimited value which we didn't recognize. This should never happen.".}
    elif type(preResult) is CastableLengthDelimitedTypes:
      var byteResult: seq[byte] = newSeq[byte](len)
      if not substream.readInto(byteResult):
        raise newException(ProtobufEOFError, "Couldn't read the length delimited buffer from this stream despite verifying it's readable.")
      preResult = cast[type(preResult)](byteResult)
    elif B.isStdlib():
      substream.stdlibFromProtobuf(preResult)
    elif preResult is object:
      preResult = substream.readValueInternal(type(preResult))
    else:
      {.fatal: "Tried to read a Length Delimited type which wasn't actually Length Delimited.".}

  box(fieldVar, preResult)

proc setField[T](value: var T, stream: InputStream, key: ProtobufKey) =
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

  elif T.isStdlib():
    stream.readLengthDelimited(value, key)

  else:
    discard """
    #Verify the field number.
    var fieldNumber = key.fieldNumber
    if (fieldNumber == 0) or (fieldNumber > T.totalSerializedFields):
      raise newException(ProtobufMessageError, "Unknown field number specified: " & $fieldNumber)

    when T.totalSerializedFields > 0:
      #Generally, once we generate this table, we'd need to verify the reader exists.
      #That said, the readers are indexed by string name, and we have an absolute list of field names.
      #Since Protobuf doesn't specify field names, just field index, and we verify said index above...
      T.fieldReadersTable(ProtobufReader).findFieldReader(fieldName, 0)(value, reader)
    discard """

    #This iterative approach is extemely poor.
    var
      counter = 1'u8
      fieldNumber = key.number
    if (fieldNumber == 0) or (uint(fieldNumber) > uint(totalSerializedFields(T))):
      raise newException(ProtobufMessageError, "Unknown field number specified: " & $fieldNumber)

    enumInstanceSerializedFields(value, fieldName, fieldVar):
      discard fieldName

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

proc readValueInternal[T](stream: InputStream, ty: typedesc[T]): T =
  while stream.readable():
    result.setField(stream, stream.readProtobufKey())

proc readValue*(reader: ProtobufReader, value: var auto) =
  if not reader.stream.readable():
    return

  if reader.keyOverride.isNone():
    box(value, reader.stream.readValueInternal(flatType(type(value))))
  else:
    var preResult: flatType(type(value))
    while reader.stream.readable():
      preResult.setField(reader.stream, reader.keyOverride.get())
    box(value, preResult)

  if reader.closeAfter:
    reader.stream.close()
