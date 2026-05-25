import ../../protobuf_serialization

type
  Int32Ext = object
    x: int32

  Proto2Int32Ext {.proto3.} = object
    a {.fieldNumber: 1, ext.}: seq[Int32Ext]

Protobuf.extensionDefaults(Int32Ext, defaultSeq = false, packed = false)

# Missing seq[Int32Ext] serializer

func computeFieldSize(
    field: int,
    value: Int32Ext,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  computeFieldSize(field, value.x, pint32, skipDefault)

proc writeField(
    stream: OutputStream,
    field: int,
    value: Int32Ext,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  writeField(stream, field, value.x, pint32, skipDefault)

proc readFieldInto(
    stream: InputStream,
    value: var Int32Ext,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  readFieldInto(stream, value.x, header, pint32)

discard Protobuf.encode(Proto2Int32Ext())
