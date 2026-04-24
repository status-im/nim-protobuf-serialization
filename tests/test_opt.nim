# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2, results

import ../protobuf_serialization
import ../protobuf_serialization/codec
import ../protobuf_serialization/sizer
import ../protobuf_serialization/internal

template flatType[T](value: Opt[T]): type = T

template isOptional(_: type Protobuf, FieldType: type Opt): bool =
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

proc readFieldInto(
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

type
  OneOption {.proto2.} = object
    a {.fieldNumber: 1, pint.}: Opt[int32]

  FullOfDefaults {.proto2.} = object
    a {.fieldNumber: 2.}: Opt[string]
    b {.fieldNumber: 3.}: Opt[OneOption]

suite "Test results Opt[T]":
  test "Handles default":
    var fod: FullOfDefaults = FullOfDefaults(b: Opt.some(OneOption(a: Opt.some(123'i32))))
    check:
      Protobuf.decode(Protobuf.encode(fod), FullOfDefaults).a.isNone()
      Protobuf.decode(Protobuf.encode(fod), FullOfDefaults).b.isSome()
      Protobuf.decode(Protobuf.encode(fod), FullOfDefaults).b.get().a.get() == 123'i32
