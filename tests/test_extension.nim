# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  unittest2,
  ./utils,
  ../protobuf_serialization,
  ../protobuf_serialization/pkg/results

type
  Int32Ext = object
    x: int32

  Proto2Int32ExtOpt {.proto2.} = object
    a {.fieldNumber: 1, ext.}: Opt[Int32Ext]

  Proto2Int32ExtPBOpt {.proto2.} = object
    a {.fieldNumber: 1, ext.}: PBOption[default(Int32Ext)]

  Proto2Int32ExtReq {.proto2.} = object
    a {.fieldNumber: 1, required, ext.}: Int32Ext

  Proto2Int32ExtSeq {.proto2.} = object
    a {.fieldNumber: 1, ext.}: seq[Int32Ext]

  Proto3Int32Ext {.proto3.} = object
    a {.fieldNumber: 1, ext.}: Int32Ext

  Proto3Int32ExtSeq {.proto3.} = object
    a {.fieldNumber: 1, ext.}: seq[Int32Ext]

Protobuf.extensionDefaults(Int32Ext, defaultSeq = true, packed = false)

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

suite "Test Int32Ext":
  test "proto2 opt Int32Ext":
    roundtrip(Proto2Int32ExtOpt(a: Opt.some(Int32Ext(x: 1'i32))), "0801")
    roundtrip(Proto2Int32ExtOpt(a: Opt.some(Int32Ext(x: 0'i32))), "0800")
    roundtrip(Proto2Int32ExtOpt(a: Opt.none(Int32Ext)), "")

  test "proto2 optional Int32Ext":
    roundtrip(Proto2Int32ExtPBOpt(a: pbSome(Int32Ext(x: 1'i32))), "0801")
    roundtrip(Proto2Int32ExtPBOpt(a: pbSome(Int32Ext(x: 0'i32))), "0800")
    roundtrip(Proto2Int32ExtPBOpt(a: pbNone(default(Int32Ext))), "")

  test "proto2 required Int32Ext":
    roundtrip(Proto2Int32ExtReq(a: Int32Ext(x: 1'i32)), "0801")
    roundtrip(Proto2Int32ExtReq(a: Int32Ext(x: 0'i32)), "0800")
    roundtrip(default(Proto2Int32ExtReq), "0800")

  test "proto2 repeated Int32Ext":
    roundtrip(Proto2Int32ExtSeq(a: @[Int32Ext(x: 1'i32)]), "0801")
    roundtrip(Proto2Int32ExtSeq(a: @[Int32Ext(x: 0'i32)]), "0800")
    roundtrip(default(Proto2Int32ExtSeq), "")
    roundtrip(Proto2Int32ExtSeq(a: @[Int32Ext(x: 1'i32), Int32Ext(x: 0'i32)]), "08010800")

  test "proto3 optional Int32Ext":
    roundtrip(Proto3Int32Ext(a: Int32Ext(x: 1'i32)), "0801")
    roundtrip(Proto3Int32Ext(a: Int32Ext(x: 0'i32)), "")
    roundtrip(default(Proto3Int32Ext), "")

  test "proto3 repeated Int32Ext":
    roundtrip(Proto3Int32ExtSeq(a: @[Int32Ext(x: 1'i32)]), "0801")
    roundtrip(Proto3Int32ExtSeq(a: @[Int32Ext(x: 0'i32)]), "0800")
    roundtrip(default(Proto3Int32ExtSeq), "")
    roundtrip(Proto3Int32ExtSeq(a: @[Int32Ext(x: 1'i32), Int32Ext(x: 0'i32)]), "08010800")
