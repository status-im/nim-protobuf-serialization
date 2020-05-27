#Parses the Protobuf binary wire protocol into the specified type.

import options

import stew/shims/macros
import faststreams/inputs
import serialization

import internal
import types

const WIRE_TYPE_MASK = 0b0000_0111'u32

proc readProtobufKey(
  stream: InputStream
): ProtobufKey =
  let
    varint = stream.decodeVarInt(uint32, PInt(uint32))
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
  var value: T

  when sizeof(T) == 8:
    if key.wire != Fixed64:
      raise newException(ProtobufMessageError, "Invalid wire type for a Fixed64.")
  else:
    if key.wire != Fixed32:
      raise newException(ProtobufMessageError, "Invalid wire type for a Fixed32.")

  stream.decodeFixed(value)
  box(fieldVar, value)

include stdlib_readers

proc readValueInternal[T](stream: InputStream, ty: typedesc[T]): T

proc readLengthDelimited[R, B](
  stream: InputStream,
  rootType: typedesc[R],
  fieldName: static string,
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

  when preResult is CastableLengthDelimitedTypes:
    var byteResult: seq[byte] = newSeq[byte](len)
    if not stream.readInto(byteResult):
      raise newException(ProtobufEOFError, "Couldn't read the length delimited buffer from this stream.")
    preResult = cast[type(preResult)](byteResult)

  else:
    if not stream.readable(len):
      raise newException(ProtobufEOFError, "Couldn't read the length delimited buffer from this stream despite expecting one.")

    stream.withReadableRange(len, substream):
      when preResult is not LengthDelimitedTypes:
        {.fatal: "Tried to read a Length Delimited value which we didn't recognize. This should never happen.".}
      elif B.isStdlib():
        substream.stdlibFromProtobuf(rootType, fieldName, preResult)
      elif preResult is (object or tuple):
        preResult = substream.readValueInternal(type(preResult))
      else:
        {.fatal: "Tried to read a Length Delimited type which wasn't actually Length Delimited.".}

  box(fieldVar, preResult)

proc setField[T](
  value: var T,
  stream: InputStream,
  key: ProtobufKey
) =
  when T is (ref or ptr or Option):
    {.fatal: "Ref or Ptr or Option made it to setField. This should never happen.".}

  elif T is not (object or tuple):
    when T is VarIntWrapped:
      stream.readVarInt(value, value, key)
    elif T is FixedWrapped:
      stream.readFixed(value, key)
    elif T is (PlatformDependentTypes or VarIntTypes or FixedTypes):
      {.fatal: "Reading into a number requires specifying both the amount of bits via the type, as well as the encoding format.".}
    else:
      stream.readLengthDelimited(type(value), "", value, key)

  elif T.isStdlib():
    stream.readLengthDelimited(type(value), "", value, key)

  else:
    #This iterative approach is extemely poor.
    var
      keyNumber = key.number
      foundKey = false

    enumInstanceSerializedFields(value, fieldName, fieldVar):
      discard fieldName

      when fieldVar is PlatformDependentTypes:
        {.fatal: "Reading into a number requires specifying the amount of bits via the type.".}

      if keyNumber == fieldVar.getCustomPragmaVal(fieldNumber):
        #Mark the key as found.
        foundKey = true

        #Only calculate the encoding VarInt.
        #In every other case, the type is enough.
        #We don't need to track the boolean type as literally every encoding will parse to the same true/false.
        var flattened: flatType(fieldVar)
        when flattened is VarIntWrapped:
          stream.readVarInt(flattened, flattened, key)

        elif flattened is FixedWrapped:
          stream.readFixed(flattened, key)

        elif flattened is VarIntTypes:
          const
            hasPInt = T.hasCustomPragmaFixed(fieldName, pint)
            hasSInt = T.hasCustomPragmaFixed(fieldName, sint)
            hasLInt = T.hasCustomPragmaFixed(fieldName, lint)
            hasFixed = T.hasCustomPragmaFixed(fieldName, fixed)
          when hasPInt:
            stream.readVarInt(flattened, PInt(flattened), key)
          elif hasSInt:
            stream.readVarInt(flattened, SInt(flattened), key)
          elif hasLInt:
            stream.readVarInt(flattened, LInt(flattened), key)
          elif hasFixed:
            stream.readFixed(flattened, key)
          else:
            {.fatal: "Encoding pragma specified yet no enoding matched. This should never happen.".}

        else:
          stream.readLengthDelimited(type(value), fieldName, flattened, key)

        box(fieldVar, flattened)
        break

    if not foundKey:
      raise newException(ProtobufMessageError, "Unknown field number specified: " & $keyNumber)

proc readValueInternal[T](stream: InputStream, ty: typedesc[T]): T =
  static: verifySerializable(flatType(T))

  while stream.readable():
    result.setField(stream, stream.readProtobufKey())

proc extractFieldAsBytes[T](
  unpacked: InputStream,
  ty: typedesc[T],
  key: ProtobufKey
): seq[byte] =
  if key.wire == VarInt:
    var next = VAR_INT_CONTINUATION_MASK
    while next == VAR_INT_CONTINUATION_MASK:
      if not unpacked.readable():
        raise newException(ProtobufEOFError, "Couldn't extract the next VarInt.")
      next = unpacked.read()
      result.add(next)

  elif key.wire == Fixed32:
    result.setLen(4)
    if not unpacked.readInto(result):
      raise newException(ProtobufEOFError, "Couldn't extract the next Fixed32.")

  elif key.wire == Fixed64:
    result.setLen(8)
    if not unpacked.readInto(result):
      raise newException(ProtobufEOFError, "Couldn't extract the next Fixed64.")

  elif key.wire == LengthDelimited:
    result.setLen(unpacked.decodeVarInt(int, PInt(int32)))
    if not unpacked.readInto(result):
      raise newException(ProtobufEOFError, "Couldn't extract the next buffer.")

proc packIntoSeq[T](
  unpacked: InputStream,
  container: typedesc[seq[T] or openArray[T] or set[T] or HashSet[T]]
): InputStream =
  var
    key: ProtobufKey = unpacked.readProtobufKey()
    values: seq[seq[byte]]
    totalLen: int
    output: OutputStream = memoryOutput()

  while unpacked.readable():
    values.add(unpacked.extractFieldAsBytes(T, key))
    totalLen += values[^1].len
    if unpacked.readable():
      key = unpacked.readProtobufKey()

  output.encodeVarInt(PInt((int32(key.number) shl 3) or int32(LengthDelimited)))
  output.encodeVarInt(PInt(totalLen))

  for value in values:
    output.write(value)

  result = memoryInput(output.getOutput())
  output.close()

proc packIntoSeq[C, T](
  unpacked: InputStream,
  container: typedesc[array[C, T]]
): InputStream =
  unpacked.packIntoSeq(seq[T])

proc pack[T](unpacked: InputStream, rootType: typedesc[T]): InputStream =
  when T is object:
    while unpacked.readable():
      var key: ProtobufKey = unpacked.readProtobufKey()
      discard key
      #var (key, value) = unpacked.extractFieldAsBytes()
      var inst: T
      enumInstanceSerializedFields(inst, fieldName, fieldVar):
        discard fieldName
        discard fieldVar
    result = memoryInput(newSeq[byte]())
  elif T is (array or seq or set or HashSet):
    result = unpacked.packIntoSeq(T)
  else:
    result = unpacked

proc readValue*(reader: ProtobufReader, value: var auto) =
  reader.stream = reader.stream.pack(flatType(value))
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
