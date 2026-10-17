# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

import
  ../[reader, writer, sizer, internal, extension]

from stew/enums import contains, checkedEnumAssign

## This is not conformant with protobuf enums. It implements
## *Closed* enums, but unknown values are not stored at all.
## So, unknown values cannot be serialized back.
## It can be used in proto2, with this caveat.
## A int32 pint can be used instead of this, which is conformant with proto3.

Protobuf.extensionDefaults(enum, pint32, defaultSeq = true)

func validateEnumType(T: type enum, ProtoType: type ProtobufExt) =
  bind contains
  const
    isProto3 = ProtoType.RootType.isProto3()
    isProto = ProtoType.RootType.isProto()
  when 0 notin T and (isProto3 or isProto):
    {.fatal: $T & " definition must contain a constant that maps to zero".}

func computeFieldSize*(
    field: int,
    value: enum,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  validateEnumType(typeof(value), ProtoType)
  computeFieldSize(field, int32(value.ord()), pint32, skipDefault)

proc writeField*(
    stream: OutputStream,
    field: int,
    value: enum,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  validateEnumType(typeof(value), ProtoType)
  writeField(stream, field, int32(value.ord()), pint32, skipDefault)

proc readFieldInto*(
    stream: InputStream,
    value: var enum,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  validateEnumType(typeof(value), ProtoType)
  if header.kind() == wireKind(pint32):
    let enumValue = stream.readValue(pint32)
    checkedEnumAssign(value, enumValue.int32)
  else:
    false

func computeFieldSizePacked*(
    field: int,
    value: openArray[enum],
    ProtoType: type ProtobufExt
): int =
  validateEnumType(typeof(value[0]), ProtoType)
  computeFieldSizePackedIt(field, value, pint32, int32(it.ord()))

proc writeFieldPacked*(
    stream: OutputStream,
    field: int,
    value: openArray[enum],
    ProtoType: type ProtobufExt
) {.raises: [IOError].} =
  validateEnumType(typeof(value[0]), ProtoType)
  writeFieldPackedIt(stream, field, value, pint32, int32(it.ord()))

proc readFieldPackedInto*(
  stream: InputStream,
  value: var seq[enum],
  header: FieldHeader,
  ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  type T = typeof(value[0])
  validateEnumType(T, ProtoType)
  var v = default(T)
  readFieldPackedIntoIt(stream, header, pint32):
    if checkedEnumAssign(v, it):
      value.add v
