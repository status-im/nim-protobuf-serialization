#Writes the specified type into a buffer using the Protobuf binary wire format.

import stew/shims/macros
import faststreams/output_stream
import serialization

import internal
import types

const LAST_BYTE = 0b1111_1111

type ProtobufWriteError* = object of ProtobufError

#Create a field key.
template key(fieldNum: uint, wire: ProtoWireType): byte =
  ((byte(fieldNum shl 3)) or wire.byte).byte

#Get the unsigned absolute value of a number.
#Used when encoding numbers.
template uabs[U](number: VarIntTypes): U =
  if number < type(number)(0):
    not cast[U](number)
  else:
    U(number)

#Created in response to https://github.com/kayabaNerve/nim-protobuf-serialization/issues/5.
var counter {.compileTime.}: int
proc verifyWritable[T]() {.compileTime.} =
  when T is PlatformDependentTypes:
    {.fatal: "Writing a number requires specifying the amount of bits via the type.".}
  elif T is (object or ref):
    counter = 0
    when T is ref:
      var tInstance = T()[]
    else:
      var tInstance = T()

    #We could use totalSerializedFields for this.
    #That said, we need to iterate over every field anyways.
    enumInstanceSerializedFields(tInstance, _, fieldVar):
      inc(counter)
      when T is PlatformDependentTypes:
        {.fatal: "Writing a number requires specifying the amount of bits via the type.".}
    if counter > 32:
      raise newException(Defect, "Object has too many fields; Protobuf has a maximum of 32.")

proc writeVarInt(
  stream: OutputStreamHandle,
  fieldNum: uint,
  value: VarIntTypes,
  subtype: VarIntSubType
) {.raises: [Defect, IOError].} =
  when sizeof(value) == 8:
    type U = uint64
  else:
    type U = uint32

  #If the value is 0, don't bother encoding it.
  #This can cause a negative overflow, which will wrap to 0.
  #That's why we use an explicit cast which requires the binary be 0'd.
  if cast[U](value) == 0:
    return

  stream.s.cursor.append(key(fieldNum, VarInt))

  var
    #Get the unsigned value which is what will be encoded.
    raw: U = uabs[U](value)
    #Written bytes.
    #This can be replaced with a countLeadingZeroBits solution so it's O(1), not O(n).
    #That said, while it'd have better complexity, it may not be faster.
    bytesWritten: uint = 0

  #If we're using SInt, we need to transform the value to its zig-zagged equivalent.
  if subtype == SIntSubType:
    raw = (raw shl 1) xor (raw shr ((sizeof(raw) * 8) - 1))
    if value < type(value)(0):
      inc(raw)

  #Write the VarInt.
  while raw > type(raw)(VAR_INT_VALUE_MASK):
    #We could convert raw to a byte, but that'll trigger a bounds check.
    stream.s.cursor.append(byte(raw and U(VAR_INT_VALUE_MASK)) or VAR_INT_CONTINUATION_MASK)
    raw = raw shr 7
    inc(bytesWritten)

  #If this was a positive number, or zig-zagged, we only need to write this last byte.
  if (value >= type(value)(0)) or (subtype == SIntSubType):
    stream.s.cursor.append(byte(raw))
  #We need to write blank bytes until the length is 10.
  else:
    stream.s.cursor.append(byte(raw) or VAR_INT_CONTINUATION_MASK)
    while bytesWritten < 9:
      stream.s.cursor.append(VAR_INT_CONTINUATION_MASK)
      inc(bytesWritten)
    stream.s.cursor.append(byte(0))

proc writeFixed64(
  stream: OutputStreamHandle,
  fieldNum: uint,
  value: Fixed64Types
) {.raises: [Defect, IOError].} =
  var raw = cast[uint64](value)
  if raw == 0:
    return
  stream.s.cursor.append(key(fieldNum, Fixed64))
  for _ in 0 ..< 8:
    stream.s.cursor.append(byte(raw and LAST_BYTE))
    raw = raw shr 8

#This has a XDeclaredButNotUsed false positive for some reason.
proc writeValueInternal*[T](
  value: T,
  existingLength: var int
): seq[byte] {.raises: [Defect, IOError, ProtobufWriteError].}

proc writeLengthDelimited(
  stream: OutputStreamHandle,
  fieldNum: uint,
  value: LengthDelimitedTypes,
  existingLength: var int
) {.raises: [Defect, IOError, ProtobufWriteError].} =
  existingLength += 2
  if existingLength > 255:
    raise newException(ProtobufWriteError, "Too long length-delimited buffer when recursively entering writeLengthDelimited.")

  when value is CastableLengthDelimitedTypes:
    if value.len == 0:
      existingLength -= 2
      return

    existingLength += value.len
    if existingLength > 255:
      raise newException(ProtobufWriteError, "Too long length-delimited buffer when casting a string/seq.")

    stream.s.cursor.append(key(fieldNum, LengthDelimited))
    stream.s.cursor.append(byte(value.len))
    for b in cast[seq[byte]](value):
      stream.s.cursor.append(b)

  elif value is (object or ref):
    let bytes = writeValueInternal(value, existingLength)
    if bytes.len == 0:
      existingLength -= 2
      return

    existingLength += bytes.len
    if existingLength > 255:
      raise newException(ProtobufWriteError, "Too long length-delimited buffer when handling a nested object.")

    stream.s.cursor.append(key(fieldNum, LengthDelimited))
    stream.s.cursor.append(byte(bytes.len))
    for b in bytes:
      stream.s.cursor.append(b)

  else:
    let bytes = value.toProtobuf()
    if bytes.len == 0:
      existingLength -= 2
      return

    existingLength += bytes.len
    if existingLength > 255:
      raise newException(ProtobufWriteError, "Too long length-delimited buffer returned from toProtobuf.")

    stream.s.cursor.append(key(fieldNum, LengthDelimited))
    stream.s.cursor.append(byte(bytes.len))
    for b in bytes:
      stream.s.cursor.append(b)

proc writeFixed32(
  stream: OutputStreamHandle,
  fieldNum: uint,
  value: Fixed32Types
) {.raises: [Defect, IOError].} =
  var raw = cast[uint32](value)
  if raw == 0:
    return
  stream.s.cursor.append(key(fieldNum, Fixed32))
  for _ in 0 ..< 4:
    stream.s.cursor.append(byte(raw and LAST_BYTE))
    raw = raw shr 8

proc writeFieldInternal[T](
  writer: ProtobufWriter,
  value: T,
  field: static string,
  existingLength: var int
) {.raises: [Defect, IOError, ProtobufWriteError].} =
  #Fake raise, as this is only raised for a subset of types yet it's in raises.
  if false:
    raise newException(ProtobufWriteError, "")

  var counter = 1'u
  when value is ref:
    var actualValue = value[]
  else:
    var actualValue = value
  enumInstanceSerializedFields(actualValue, fieldName, fieldVar):
    if field != fieldName:
      inc(counter)
    else:
      #Either VarInt of Fixed.
      when fieldVar is VarIntTypes:
        #We need to grab the subtype off the type definition.
        #That said, hasCustomPragmaFixed doesn't work with ref types.
        #We need to define a custom one in that case which will work.
        #This is a hack which isn't guaranteed to maintain compatiblity with hasCustomPragmaFixed.
        when getTypeImpl(T).kind == nnkRefTy:
          macro hCP(field: static string, pragma: typed{nkSym}): untyped =
            var actualT = newNimNode(nnkTypeDef).add(
              T.getTypeImpl()[0],
              newNimNode(nnkEmpty),
              T.getTypeImpl()[0].getImpl()[2][0]
            )
            for f in recordFields(actualT):
              var thisField = f.name
              if thisField.kind == nnkAccQuoted: thisField = thisField[0]
              if eqIdent(thisField, field):
                return newLit(f.pragmas.findPragma(pragma) != nil)
        else:
          template hCP(field: static string, pragma: typed{nkSym}): untyped =
            T.hasCustomPragmaFixed(field, pragma)

        when hCP(fieldName, pint):
          writer.stream.writeVarInt(counter, fieldVar, PIntSubType)
        elif hCP(fieldName, puint):
          writer.stream.writeVarInt(counter, fieldVar, UIntSubType)
        elif hCP(fieldName, sint):
          writer.stream.writeVarInt(counter, fieldVar, SIntSubType)
        #If this is actually a Fixed field, which has a type overlap with VarInt, write it as one.
        elif hCP(fieldName, fixed) or hCP(fieldName, sfixed):
          when sizeof(fieldVar) == 8:
            writer.stream.writeFixed64(counter, fieldVar)
          else:
            writer.stream.writeFixed32(counter, fieldVar)
        #This default is okay as any encoding of a boolean will produce the same truthy/falsey value.
        elif fieldVar is bool:
          writer.stream.writeVarInt(counter, fieldVar, UIntSubType)
        else:
          {.fatal: "Writing a number requires specifying the encoding via a SInt/PIntUInt/Fixed/SFixed wrapping call.".}
      #Float64.
      elif fieldVar is Fixed64Types:
        writer.stream.writeFixed64(counter, fieldVar)
      #Float32.
      elif fieldVar is Fixed32Types:
        writer.stream.writeFixed32(counter, fieldVar)
      #Length delimited.
      else:
        writer.stream.writeLengthDelimited(counter, fieldVar, existingLength)

template writeField*[T](
  writer: ProtobufWriter,
  value: T,
  field: static string
) =
  var existingLength = 0
  writeFieldInternal(writer, value, field, existingLength)

proc writeValueInternal[T](
  value: T,
  existingLength: var int
): seq[byte] {.raises: [Defect, IOError, ProtobufWriteError].} =
  if false:
    raise newException(ProtobufWriteError, "")

  let writer: ProtobufWriter = newProtobufWriter()

  when T is VarIntTypes:
    when T is (PIntWrapped32 or PIntWrapped64):
      writer.stream.writeVarInt(1, value.unwrap(), PIntSubType)
    elif T is (UIntWrapped32 or UIntWrapped64):
      writer.stream.writeVarInt(1, value.unwrap(), UIntSubType)
    elif T is bool:
      writer.stream.writeVarInt(1, value, UIntSubType)
    elif T is (SIntWrapped32 or SIntWrapped64):
      writer.stream.writeVarInt(1, value.unwrap(), SIntSubType)
    elif T is (FixedWrapped64 or SFixedWrapped64):
      writer.stream.writeFixed64(1, value)
    elif T is (FixedWrapped32 or SFixedWrapped32):
      writer.stream.writeFixed32(1, value)
    else:
      {.fatal: "Writing a number requires specifying the encoding via a SInt/PIntUInt/Fixed/SFixed wrapping call.".}
  elif T is Fixed64Types:
    writer.stream.writeFixed64(1, value)
  elif T is Fixed32Types:
    writer.stream.writeFixed32(1, value)
  elif T is (object or ref):
    when T is ref:
      if value.isNil:
        return
      enumInstanceSerializedFields(value[], fieldName, _):
        writer.writeFieldInternal(value, fieldName, existingLength)
    else:
      enumInstanceSerializedFields(value, fieldName, _):
        writer.writeFieldInternal(value, fieldName, existingLength)
  else:
    writer.stream.writeLengthDelimited(1, value, existingLength)

  return writer.buffer()

template writeValue*[T](
  value: T
): seq[byte] =
  when T is object:
    static:
      verifyWritable[T]()
  var existingLength = 0
  writeValueInternal(value, existingLength)
