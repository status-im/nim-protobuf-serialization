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
  pkg/results,
  ../[reader, writer, sizer, internal, format]

export results

template flatType*[T](value: Opt[T]): type = T

template isOptional*(_: type Protobuf, FieldType: type Opt): bool =
  true

proc computeFieldSize*(
    fieldNum: int,
    fieldVal: Opt,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  protoType(InnerProtoType, ProtoType.RootType, flatType(fieldVal), ProtoType.fieldName)
  if fieldVal.isSome():
    computeFieldSize(fieldNum, fieldVal.get(), InnerProtoType, skipDefault)
  else:
    0

proc writeField*(
    stream: OutputStream,
    fieldNum: int,
    fieldVal: Opt,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  protoType(InnerProtoType, ProtoType.RootType, flatType(fieldVal), ProtoType.fieldName)
  if fieldVal.isSome():
    stream.writeField(fieldNum, fieldVal.get(), InnerProtoType, skipDefault)

proc readFieldInto*(
    stream: InputStream,
    value: var Opt,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  protoType(InnerProtoType, ProtoType.RootType, flatType(value), ProtoType.fieldName)
  var val: typeof(value.get())
  if stream.readFieldInto(val, header, InnerProtoType):
    value = Opt.ok(val)
    true
  else:
    false
