#Parses the Protobuf binary wire protocol into the specified type.

import
  std/[typetraits, sets],
  stew/assign2,
  stew/shims/macros,
  faststreams/inputs,
  serialization,
  "."/[codec, internal, types]

export inputs, serialization, codec, types

proc readValueInternal[T: object](stream: InputStream, value: var T, silent: bool = false)

macro unsupported(T: typed): untyped =
  error "Assignment of the type " & humaneTypeName(T) & " is not supported"

template requireKind(header: FieldHeader, expected: WireKind) =
  mixin number
  if header.kind() != expected:
    raise (ref ValueError)(
      msg: "Unexpected data kind " & $(header.number()) & ": " & $header.kind()  &
      ", exprected " & $expected)

proc readFieldInto[T: object](
  stream: InputStream,
  value: var T,
  header: FieldHeader,
  ProtoType: type
) =
  header.requireKind(WireKind.LengthDelim)

  let len = stream.readLength()
  if len > 0:
    # TODO: https://github.com/status-im/nim-faststreams/issues/31
    # TODO: check that all bytes were read
    # stream.withReadableRange(len, inner):
    #   inner.readValueInternal(value)

    var tmp = newSeqUninitialized[byte](len)
    if not stream.readInto(tmp):
      raise (ref ValueError)(msg: "not enough bytes")
    memoryInput(tmp).readValueInternal(value)

proc readFieldInto[T: not object and (seq[byte] or not seq)](
  stream: InputStream,
  value: var T,
  header: FieldHeader,
  ProtoType: type
) =
  when ProtoType is SomeVarint:
    header.requireKind(WireKind.Varint)
    assign(value, T(stream.readVarint(ProtoType)))
  elif ProtoType is SomeFixed64:
    header.requireKind(WireKind.Fixed64)
    assign(value, T(stream.readFixed(ProtoType)))
  elif ProtoType is SomeLengthDelim:
    header.requireKind(WireKind.LengthDelim)
    assign(value, T(stream.readLengthDelim(ProtoType)))
  elif ProtoType is SomeFixed32:
    header.requireKind(WireKind.Fixed32)
    assign(value, T(stream.readFixed(ProtoType)))
  else:
    static: unsupported(ProtoType)

proc readFieldInto[T: not byte](
  stream: InputStream,
  value: var seq[T],
  header: FieldHeader,
  ProtoType: type
) =
  value.add(default(T))
  stream.readFieldInto(value[^1], header, ProtoType)

proc readFieldInto(
  stream: InputStream,
  value: var PBOption,
  header: FieldHeader,
  ProtoType: type
) =
  stream.readFieldInto(value.mget(), header, ProtoType)

proc readFieldPackedInto[T](
  stream: InputStream,
  value: var seq[T],
  header: FieldHeader,
  ProtoType: type
) =
  # TODO make more efficient
  var
    bytes = seq[byte](stream.readLengthDelim(pbytes))
    inner = memoryInput(bytes)
  while inner.readable():
    value.add(default(T))

    let kind = when ProtoType is SomeVarint:
      WireKind.Varint
    elif ProtoType is SomeFixed32:
      WireKind.Fixed32
    else:
      static: doAssert ProtoType is SomeFixed64
      ProtoType.SomeFixed64

    inner.readFieldInto(value[^1], FieldHeader.init(header.number, kind), ProtoType)

proc readValueInternal[T: object](stream: InputStream, value: var T, silent: bool = false) =
  var requiredSets: HashSet[int]
  when T.hasCustomPragma(protobuf2):
    if not silent:
      var i: int = -1
      enumInstanceSerializedFields(value, fieldName, fieldVar):
        inc(i)

        when T.hasCustomPragmaFixed(fieldName, required):
          requiredSets.incl(i)

  const
    isProto3 = T.hasCustomPragma(protobuf3)

  while stream.readable():
    let header = stream.readHeader()
    var i = -1
    enumInstanceSerializedFields(value, fieldName, fieldVar):
      inc i
      const
        fieldNum = T.fieldNumberOf(fieldName)
        packed = isProto3 or T.isPacked(fieldName)

      if header.number() == fieldNum:
        if not silent: requiredSets.excl i

        protoType(ProtoType, T, typeof(fieldVar), fieldName)

        # TODO should we allow reading packed fields into non-repeated fields?
        when ProtoType is SomePrimitive and fieldVar is seq and fieldVar isnot seq[byte]:
          if header.kind() == WireKind.LengthDelim:
            stream.readFieldPackedInto(fieldVar, header, ProtoType)
          else:
            stream.readFieldInto(fieldVar, header, ProtoType)
        else:
          stream.readFieldInto(fieldVar, header, ProtoType)

  if (requiredSets.len != 0):
    raise newException(ProtobufReadError, "Message didn't encode a required field: " & $requiredSets)

proc readValue*[T: object](reader: ProtobufReader, value: var T) =
  static: verifySerializable(T)

  # TODO skip length header
  try:
    reader.stream.readValueInternal(value)
  finally:
    if reader.closeAfter:
      reader.stream.close()
