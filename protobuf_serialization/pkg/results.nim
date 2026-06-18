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
  ../[reader, writer, sizer, internal, format, extension]

export results

func supportsPacked*(_: type Opt, ProtoType: type ProtobufExt): bool =
  false

template flatType*[U](T: type Protobuf, value: Opt[U]): type = U

func isExtension*(T: type Protobuf, FieldType: type Opt): bool = true

func validateOptType(T: type Opt, ProtoType: type ProtobufExt) =
  type FlatType = Protobuf.flatType(default(T))
  when FlatType is seq and FlatType isnot seq[byte]:
    {.error: $ProtoType.RootType & "." & $ProtoType.fieldName & ": optional-repeated Opt[seq] type is not allowed.".}
  elif FlatType is Opt:
    {.error: $ProtoType.RootType & "." & $ProtoType.fieldName & ": optional-optional Opt[Opt[T]] type is not allowed.".}
  elif FlatType is PBOption:
    {.error: $ProtoType.RootType & "." & $ProtoType.fieldName & ": optional-optional Opt[PBOption[T]] type is not allowed.".}

func computeFieldSize*(
    field: int,
    value: Opt,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  validateOptType(typeof(value), ProtoType)
  protoType(InnerProtoType, ProtoType.RootType, Protobuf.flatType(value), ProtoType.fieldName)
  if value.isSome():
    computeFieldSize(field, value.get(), InnerProtoType, false)
  else:
    0

proc writeField*(
    stream: OutputStream,
    field: int,
    value: Opt,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  validateOptType(typeof(value), ProtoType)
  protoType(InnerProtoType, ProtoType.RootType, Protobuf.flatType(value), ProtoType.fieldName)
  if value.isSome():
    stream.writeField(field, value.get(), InnerProtoType, false)

proc readFieldInto*(
    stream: InputStream,
    value: var Opt,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  validateOptType(typeof(value), ProtoType)
  protoType(InnerProtoType, ProtoType.RootType, Protobuf.flatType(value), ProtoType.fieldName)
  if value.isSome():
    stream.readFieldInto(value.value(), header, InnerProtoType)
  else:
    var val: typeof(value.get())
    if stream.readFieldInto(val, header, InnerProtoType):
      value = Opt.ok(val)
      true
    else:
      false
