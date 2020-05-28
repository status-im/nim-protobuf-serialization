import sets

import faststreams

import internal
import types

proc extractFieldAsBytes*(
  unpacked: InputStream,
  key: ProtobufKey
): seq[byte] =
  if key.wire == VarInt:
    var next = VAR_INT_CONTINUATION_MASK
    while (next and VAR_INT_CONTINUATION_MASK) != 0:
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

proc packIntoSeq*[T](
  unpacked: InputStream,
  container: typedesc[seq[T] or openArray[T] or set[T] or HashSet[T]]
): InputStream =
  var
    key: ProtobufKey = unpacked.readProtobufKey()
    values: seq[seq[byte]]
    totalLen: int
    output: OutputStream = memoryOutput()

  while unpacked.readable():
    values.add(unpacked.extractFieldAsBytes(key))
    totalLen += values[^1].len
    if unpacked.readable():
      key = unpacked.readProtobufKey()

  output.writeProtobufKey(key.number, LengthDelimited)
  when (not T.isStdlib()) and (T is (object or tuple)):
    output.encodeVarInt(PInt(totalLen + values.len))
  else:
    output.encodeVarInt(PInt(totalLen))

  for value in values:
    when (not T.isStdlib()) and (T is (object or tuple)):
      output.encodeVarInt(PInt(int32(value.len)))
    output.write(value)

  result = unsafeMemoryInput(output.getOutput())
  #output.close()

proc packIntoSeq*[C, T](
  unpacked: InputStream,
  container: typedesc[array[C, T]]
): InputStream =
  unpacked.packIntoSeq(seq[T])

proc pack*[T](
  unpacked: InputStream,
  rootType: typedesc[T],
  closeAfter: var bool
): InputStream =
  var sourceIsPacked = false
  when T is (array or seq or set or HashSet):
    result = unpacked.packIntoSeq(T)
  elif T is object:
    var output = memoryOutput()
    while unpacked.readable():
      var
        key: ProtobufKey = unpacked.readProtobufKey()
        foundKey = false
        inst: T
      enumInstanceSerializedFields(inst, fieldName, fieldVar):
        when T.getCustomPragmaFixed(fieldName, fieldNumber) is int:
          if T.getCustomPragmaFixed(fieldName, fieldNumber) == key.number:
            foundKey = true

            when fieldVar is not (seq or array or set or HashSet):
              when (
                T.hasCustomPragmaFixed(fieldName, pint) or
                T.hasCustomPragmaFixed(fieldName, sint) or
                T.hasCustomPragmaFixed(fieldName, lint) or
                (fieldVar is VarIntWrapped)
              ):
                output.writeProtobufKey(key.number, VarInt)
              elif fieldVar is FixedTypes:
                when sizeof(fieldVar) == 8:
                  output.writeProtobufKey(key.number, Fixed64)
                else:
                  output.writeProtobufKey(key.number, Fixed32)
              else:
                output.writeProtobufKey(key.number, LengthDelimited)
            else:
              output.writeProtobufKey(key.number, key.wire)

            var cursor = output.delayVarSizeWrite(10)
            let startPos = output.pos
            output.write(unpacked.extractFieldAsBytes(key))
            if key.wire == LengthDelimited:
              cursor.finalWrite(encodeVarInt(PInt(int32(output.pos - startPos))))
            else:
              cursor.finalWrite([])
        else:
          {.fatal: "Field didn't have the field number pragma attached.".}

      if not foundKey:
        raise newException(ProtobufMessageError, "Unknown field number specified: " & $key.number)

    result = unsafeMemoryInput(output.getOutput())
    #output.close()
  else:
    sourceIsPacked = true
    result = unpacked

  #Only close the source stream if no parent is relying on it, and we didn't just return it.
  if (not sourceIsPacked) and closeAfter:
    closeAfter = false
    unpacked.close()
