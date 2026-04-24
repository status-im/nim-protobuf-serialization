# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  stew/objects,
  ../[reader, writer, sizer]

func computeFieldSize*[T: enum](
    fieldNum: int,
    fieldVal: T,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  computeFieldSize(fieldNum, int32(fieldVal.ord()), pint32, skipDefault)

proc writeField*[T: enum](
    stream: OutputStream,
    fieldNum: int,
    fieldVal: T,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  #when 0 notin T:
  #  {.fatal: $T & " definition must contain a constant that maps to zero".}
  writeField(stream, fieldNum, int32(fieldVal.ord()), pint32, skipDefault)

proc readFieldInto*[T: enum](
    stream: InputStream,
    value: var T,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  # TODO: This function doesn't work for proto2 edge cases. Make it work
  #when 0 notin T and T.isProto3():
  #  {.fatal: $T & " definition must contain a constant that maps to zero".}
  if header.kind() != WireKind.Varint:
    return false
  let enumValue = stream.readValue(pint32)
  if not checkedEnumAssign(value, enumValue.int32):
    discard checkedEnumAssign(value, 0)
  true
