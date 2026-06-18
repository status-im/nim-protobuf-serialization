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
  stew/byteutils,
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
    a {.fieldNumber: 1, ext, packed: false.}: seq[Int32Ext]

  OneOfKind {.pure.} = enum
    unset
    x

  OneOf {.proto3, oneof.} = object
    case kind: OneOfKind
    of OneOfKind.unset:
      discard
    of OneOfKind.x:
      x {.fieldNumber: 1, ext.}: Int32Ext

  Proto3Int32ExtOneOf {.proto3.} = object
    one {.oneof.}: OneOf

Protobuf.extensionDefaults(Int32Ext, pint32, defaultSeq = true)

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

func computeFieldSizePacked(
    field: int,
    value: seq[Int32Ext],
    ProtoType: type ProtobufExt
): int =
  var vals = default(seq[int32])
  for v in value:
    vals.add v.x
  computeFieldSizePacked(field, vals, pint32)

proc writeFieldPacked(
    stream: OutputStream,
    field: int,
    value: seq[Int32Ext],
    ProtoType: type ProtobufExt
) {.raises: [IOError].} =
  var vals = default(seq[int32])
  for v in value:
    vals.add v.x
  writeFieldPacked(stream, field, vals, pint32)

proc readFieldPackedInto(
  stream: InputStream,
  value: var seq[Int32Ext],
  header: FieldHeader,
  ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  var vals = default(seq[int32])
  if stream.readFieldPackedInto(vals, header, pint32):
    for v in vals:
      value.add Int32Ext(x: v)
    true
  else:
    false

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

  test "proto3 oneof Int32Ext":
    let encoded = "0801".hexToSeqByte
    let ret = Protobuf.decode(encoded, Proto3Int32ExtOneOf)
    check:
      ret.one.kind == OneOfKind.x
      ret.one.x == Int32Ext(x: 1'i32)
      Protobuf.encode(ret) == encoded

type
  StringExt2 = object
    x: string

  Proto3StringExt2 {.proto3.} = object
    a {.fieldNumber: 1, ext.}: seq[StringExt2]

Protobuf.extensionDefaults(StringExt2, pstring, defaultSeq = false)

func computeFieldSize(
    field: int,
    value: StringExt2,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  computeFieldSize(field, value.x, pstring, skipDefault)

proc writeField(
    stream: OutputStream,
    field: int,
    value: StringExt2,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  writeField(stream, field, value.x, pstring, skipDefault)

proc readFieldInto(
    stream: InputStream,
    value: var StringExt2,
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  readFieldInto(stream, value.x, header, pstring)

# TODO: when true: once read/write/sizer for seq[T], type[ProtobufExt] are removed
when false:
  func computeFieldSize(
      field: int, 
      value: seq[StringExt2],
      ProtoType: type ProtobufExt,
      skipDefault: static bool
  ): int =
    var dataSize = 0
    for i in 0 ..< value.len:
      dataSize += computeFieldSize(field, value[i], ProtoType, false)
    dataSize

  proc writeField(
      stream: OutputStream,
      field: int,
      value: seq[StringExt2],
      ProtoType: type ProtobufExt,
      skipDefault: static bool = false
  ) {.raises: [IOError].} =
    for i in 0 ..< value.len:
      stream.writeField(field, value[i], ProtoType, false)

  proc readFieldInto(
    stream: InputStream,
    value: var seq[StringExt2],
    header: FieldHeader,
    ProtoType: type ProtobufExt
  ): bool {.raises: [SerializationError, IOError].} =
    var val = default(typeof(value[0]))
    if stream.readFieldInto(val, header, ProtoType):
      value.add move(val)
      true
    else:
      false

suite "Test seq[T] serializer":
  test "custom seq[StringExt2] serializer":
    roundtrip(Proto3StringExt2(a: @[StringExt2(x: "abc")]), "0a03616263")
