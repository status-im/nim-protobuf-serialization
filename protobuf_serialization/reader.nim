#Parses the Protobuf binary wire protocol into the specified type.

import options

import stew/shims/macros
import faststreams/inputs
import serialization

import internal
import types

proc readVarInt[B, E](
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

proc readValueInternal[T](stream: InputStream, ty: typedesc[T], silent: bool = false): T

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
    preResult: flatType(B)
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
        {.fatal: "Tried to read a Length Delimited type which wasn't actually Length Delimited. This should never happen.".}

  box(fieldVar, preResult)

proc setField[T](
  value: var T,
  stream: InputStream,
  key: ProtobufKey,
  requiredSets: var HashSet[int]
) =
  when T is (ref or ptr or Option):
    {.fatal: "Ref or Ptr or Option made it to setField. This should never happen.".}

  elif T is (seq or set or HashSet):
    template merge[I](
      stdlib: var (seq[I] or set[I] or HashSet[I]),
      value: I
    ) =
      when stdlib is seq:
        stdlib.add(value)
      else:
        stdlib.incl(value)

    type U = value.getUnderlyingType()
    #Unpacked seq of numbers.
    if key.wire != LengthDelimited:
      var next: U
      when flatType(U) is VarIntWrapped:
        stream.readVarInt(next, next, key)
      elif flatType(U) is FixedWrapped:
        stream.readFixed(next, key)
      else:
        if true:
          raise newException(ProtobufMessageError, "Reading into an unpacked seq yet value is a number.")
      merge(value, next)
    #Packed seq of numbers/unpacked seq of objects.
    else:
      when flatType(U) is (VarIntWrapped or FixedWrapped):
        var newValues: seq[U]
        stream.readLengthDelimited(type(value), "", newValues, key)
        for newValue in newValues:
          merge(value, newValue)
      else:
        var
          next: flatType(U)
          boxed: U
        stream.readLengthDelimited(U, "", next, key)
        box(boxed, next)
        merge(value, boxed)

  elif T is not (object or tuple):
    when T is VarIntWrapped:
      stream.readVarInt(value, value, key)
    elif T is FixedWrapped:
      stream.readFixed(value, key)
    elif T is (PlatformDependentTypes or VarIntTypes or FixedTypes):
      {.fatal: "Reading into a number requires specifying both the amount of bits via the type, as well as the encoding format.".}
    else:
      stream.readLengthDelimited(type(value), "", value, key)

  else:
    #This iterative approach is extemely poor.
    #See https://github.com/kayabaNerve/nim-protobuf-serialization/issues/8.
    var
      keyNumber: int = key.number
      found: bool = false
    when T.hasCustomPragma(protobuf2):
      var rSI: int = -1

    enumInstanceSerializedFields(value, fieldName, fieldVar):
      discard fieldName
      when T.hasCustomPragma(protobuf2):
        inc(rSI)

      when fieldVar is PlatformDependentTypes:
        {.fatal: "Reading into a number requires specifying the amount of bits via the type.".}

      if keyNumber == fieldVar.getCustomPragmaVal(fieldNumber):
        found = true
        when T.hasCustomPragma(protobuf2):
          requiredSets.excl(rSI)

        var
          blank: flatType(fieldVar)
          flattened = flatMap(fieldVar).get(blank)
        when blank is (seq or set or HashSet):
          type U = flattened.getUnderlyingType()
          when U is (VarIntWrapped or FixedWrapped):
            var castedVar = flattened
          elif U is (VarIntTypes or FixedTypes):
            when T.hasCustomPragmaFixed(fieldName, pint):
              #Nim encounters an error when doing `type C = PInt(U)`.
              var
                pointless: U
                C = PInt(pointless)
            elif T.hasCustomPragmaFixed(fieldName, sint):
              var
                pointless: U
                C = SInt(pointless)
            elif T.hasCustomPragmaFixed(fieldName, fixed):
              var
                pointless: U
                C = Fixed(pointless)

            when flattened is seq:
              var castedVar = cast[seq[type(C)]](flattened)
            elif flattened is set:
              var castedVar = cast[set[type(C)]](flattened)
            elif flattened is HashSet:
              var castedVar = cast[HashSet[type(C)]](flattened)
          else:
            var castedVar = flattened
          var requiredSets: HashSet[int] = initHashSet[int]()
          castedVar.setField(stream, key, requiredSets)

          flattened = cast[type(flattened)](castedVar)
        else:
          #Only calculate the encoding for VarInt.
          #In every other case, the type is enough.
          when flattened is VarIntWrapped:
            stream.readVarInt(flattened, flattened, key)

          elif flattened is FixedWrapped:
            stream.readFixed(flattened, key)

          elif flattened is VarIntTypes:
            when T.hasCustomPragmaFixed(fieldName, pint):
              stream.readVarInt(flattened, PInt(flattened), key)
            elif T.hasCustomPragmaFixed(fieldName, sint):
              stream.readVarInt(flattened, SInt(flattened), key)
            elif T.hasCustomPragmaFixed(fieldName, fixed):
              stream.readFixed(flattened, key)
            else:
              {.fatal: "Encoding pragma specified yet no enoding matched. This should never happen.".}

          else:
            stream.readLengthDelimited(type(value), fieldName, flattened, key)

        box(fieldVar, flattened)
        break

    if not found:
      raise newException(ProtobufMessageError, "Message encoded an unknown field number.")

proc readValueInternal[T](stream: InputStream, ty: typedesc[T], silent: bool = false): T =
  static: verifySerializable(flatType(T))

  var requiredSets: HashSet[int] = initHashSet[int]()
  when (flatType(result) is object) and (not flatType(result).isStdlib()):
    when ty.hasCustomPragma(protobuf2):
      var i: int = -1
      enumInstanceSerializedFields(result, fieldName, fieldVar):
        inc(i)
        when ty.hasCustomPragmaFixed(fieldName, required):
          requiredSets.incl(i)
        else:
          when fieldVar is not (seq or set or HashSet):
            when type(fieldVar.get()) is object:
              fieldVar = pbNone(memoryInput(newSeq[char](0)).readValueInternal(type(fieldVar.get()), true))
            else:
              fieldVar = pbNone(fieldVar.getCustomPragmaVal(pbDefault)[0])

  while stream.readable():
    result.setField(stream, stream.readProtobufKey(), requiredSets)

  if (requiredSets.len != 0) and (not silent):
    raise newException(ProtobufReadError, "Message didn't encode a required field.")

proc readValue*(reader: ProtobufReader, value: var auto) =
  when value is Option:
    {.fatal: "Can't decode directly into an Option.".}

  when (flatType(value) is object) and (not flatType(value).isStdlib()):
    static:
      for c in $type(value):
        if c == ' ':
          raise newException(Exception, "Told to read into an inlined type; every type read into must have a proper type definition: " & $type(value))
    when type(value).hasCustomPragma(protobuf2):
      if not reader.stream.readable():
        enumInstanceSerializedFields(value, fieldName, fieldVar):
          when type(value).hasCustomPragmaFixed(fieldName, required):
            raise newException(ProtobufReadError, "Message didn't encode a required field.")
          else:
            when fieldVar is not (seq or set or HashSet):
              when type(fieldVar.get()) is object:
                fieldVar = pbNone(memoryInput(newSeq[char](0)).readValueInternal(type(fieldVar.get()), true))
              else:
                fieldVar = pbNone(fieldVar.getCustomPragmaVal(pbDefault)[0])
  try:
    if reader.stream.readable():
      if reader.keyOverride.isNone():
        box(value, reader.stream.readValueInternal(flatType(type(value))))
      else:
        var preResult: flatType(type(value))
        while reader.stream.readable():
          var requiredSets: HashSet[int] = initHashSet[int]()
          preResult.setField(reader.stream, reader.keyOverride.get(), requiredSets)
        box(value, preResult)
  except ProtobufReadError as e:
    raise e
  finally:
    if reader.closeAfter:
      reader.stream.close()
