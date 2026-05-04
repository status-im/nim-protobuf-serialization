#Parses the Protobuf binary wire protocol into the specified type.

{.push raises: [], gcsafe.}

import
  std/[typetraits, sets],
  stew/assign2,
  stew/objects,
  stew/shims/macros,
  faststreams/inputs,
  serialization,
  ./[codec, internal, types]

export inputs, serialization, codec, types

proc readValueInternal[T: object](stream: InputStream, value: var T, silent: bool = false) {.raises: [SerializationError, IOError].}

proc readFieldInto*[T: not seq and not PBOption](
  stream: InputStream,
  value: var T,
  header: FieldHeader,
  ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

proc readFieldPackedInto*[T](
  stream: InputStream,
  value: var T,
  header: FieldHeader,
  ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  unsupportedProtoType ProtoType.FieldType, ProtoType.RootType, ProtoType.fieldName

proc readFieldInto*[T: object and not PBOption](
  stream: InputStream,
  value: var T,
  header: FieldHeader,
  ProtoType: type pbytes
): bool {.raises: [SerializationError, IOError].} =
  if header.kind() == wireKind(ProtoType):
    let len = stream.readLength()
    if len > 0:
      # TODO: https://github.com/status-im/nim-faststreams/issues/31
      # TODO: check that all bytes were read
      # stream.withReadableRange(len, inner):
      #   inner.readValueInternal(value)

      let inputLen = stream.len()
      if inputLen.isSome() and len > inputLen.get():
        raise (ref ProtobufValueError)(msg: "Missing bytes: " & $len)

      var tmp = newSeqUninitialized[byte](len)
      if not stream.readInto(tmp):
        raise (ref ProtobufValueError)(msg: "not enough bytes")
      memoryInput(tmp).readValueInternal(value)
    true
  else:
    false

proc readFieldInto*[T: not object and (seq[byte] or not seq)](
  stream: InputStream,
  value: var T,
  header: FieldHeader,
  ProtoType: type SomeProto
): bool {.raises: [SerializationError, IOError].} =
  if header.kind() == wireKind(ProtoType):
    when ProtoType is SomeVarint:
      assign(value, T(stream.readValue(ProtoType)))
    elif ProtoType is SomeFixed64:
      assign(value, T(stream.readValue(ProtoType)))
    elif ProtoType is SomeLengthDelim:
      assign(value, T(stream.readValue(ProtoType)))
    else:
      static: doAssert ProtoType is SomeFixed32
      assign(value, T(stream.readValue(ProtoType)))
    true
  else:
    false

proc readFieldInto*[T: not byte](
  stream: InputStream,
  value: var seq[T],
  header: FieldHeader,
  ProtoType: type # SomeProto
): bool {.raises: [SerializationError, IOError].} =
  var val = default(T)
  if stream.readFieldInto(val, header, ProtoType):
    value.add move(val)
    true
  else:
    false

proc readFieldInto*(
  stream: InputStream,
  value: var PBOption,
  header: FieldHeader,
  ProtoType: type
): bool {.raises: [SerializationError, IOError].} =
  if stream.readFieldInto(value.mget(), header, ProtoType):
    true
  else:
    reset(value)
    false

proc readFieldPackedInto*[T: not byte](
  stream: InputStream,
  value: var seq[T],
  header: FieldHeader,
  ProtoType: type SomePrimitive
): bool {.raises: [SerializationError, IOError].} =
  # TODO make more efficient
  doAssert header.kind() == WireKind.LengthDelim
  var
    bytes = seq[byte](stream.readValue(pbytes))
    inner = memoryInput(bytes)
    headerElm = FieldHeader.init(header.number, wireKind(ProtoType))
  while inner.readable():
    value.add default(T)
    let r = inner.readFieldInto(value[^1], headerElm, ProtoType)
    doAssert r
  true

proc readValueInternal[T: object](stream: InputStream, value: var T, silent: bool = false) {.raises: [SerializationError, IOError].} =
  mixin supportsPacked, readFieldPackedInto

  const
    isProto2: bool = T.isProto2()

  when isProto2:
    var requiredSets: HashSet[int]
    if not silent:
      var i: int = -1
      enumInstanceSerializedFields(value, fieldName, fieldVar):
        inc(i)

        when T.hasCustomPragmaFixed(fieldName, required):
          requiredSets.incl(i)

  while stream.readable():
    let header = stream.readHeader()
    let pos = stream.pos()
    var i {.used.} = -1
    var knownField = false

    if not header.number().validFieldNumber(true):
      raise newException(ProtobufReadError, "Invalid field number: " & $header.number())

    enumInstanceSerializedFields(value, fieldName, fieldVar):
      inc i
      const
        fieldNum = T.fieldNumberOf(fieldName)

      if header.number() == fieldNum:
        protoType(ProtoType, T, typeof(fieldVar), fieldName)
        # TODO should we allow reading packed fields into non-repeated fields?
        knownField =
          when supportsPacked(typeof(fieldVar), ProtoType):
            if header.kind() == WireKind.LengthDelim:
              stream.readFieldPackedInto(fieldVar, header, ProtoType)
            else:
              stream.readFieldInto(fieldVar, header, ProtoType)
          elif typeof(fieldVar) is ref and defined(ConformanceTest):
            fieldVar = new typeof(fieldVar)
            stream.readFieldInto(fieldVar[], header, ProtoType)
          else:
            stream.readFieldInto(fieldVar, header, ProtoType)

        when isProto2:
          if not silent and knownField: requiredSets.excl i

    if not knownField and pos == stream.pos():
      case header.kind():
      of WireKind.Varint: stream.skipValue(puint64)
      of WireKind.Fixed64: stream.skipValue(fixed64)
      of WireKind.LengthDelim: stream.skipValue(pbytes)
      of WireKind.Fixed32: stream.skipValue(fixed32)

  when isProto2:
    if (requiredSets.len != 0):
      raise newException(
        ProtobufReadError,
        "Message didn't encode a required field: " & $requiredSets)

proc readValue*[T: object](reader: ProtobufReader, value: var T) {.raises: [SerializationError, IOError].} =
  static: verifySerializable(T)

  # TODO skip length header
  try:
    reader.stream.readValueInternal(value)
  finally:
    if reader.closeAfter:
      reader.stream.close()
