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
  std/[macros, typetraits],
  ../[reader, writer, sizer, internal]

from stew/objects import enumRangeInt64

## This is not conformant with protobuf enums. It implements
## *Closed* enums, but unknown values are not stored at all.
## So, unknown values cannot be serialized back.
## It can be used in proto2, with this caveat.
## A int32 pint can be used instead of this, which is conformant with proto3.

# TODO: https://github.com/status-im/nim-stew/pull/271

template hasHoles(T: type enum): bool =
  const ret = int64(T.high.ord) - int64(T.low.ord) != int64(enumLen(T) - 1)
  ret

func contains[I: SomeInteger](e: type[enum], v: I): bool =
  when I is uint64:
    if v > int64.high.uint64:
      return false
  when e.hasHoles():
    v.int64 in enumRangeInt64(e)
  else:
    v.int64 in e.low.int64 .. e.high.int64

func checkedEnumAssign[E: enum, I: SomeInteger](res: var E, value: I): bool =
  bind contains
  if value notin E:
    false
  else:
    res = cast[E](value)
    true

func supportsPacked*(T: type enum, ProtoType: type ProtobufExt): bool = false
func supportsPacked*(T: type seq[enum], ProtoType: type ProtobufExt): bool = true

func validateEnumType(T: type enum, ProtoType: type ProtobufExt) =
  bind contains
  when 0 notin T and ProtoType.RootType.isProto3():
    {.fatal: $T & " definition must contain a constant that maps to zero".}

func computeFieldSize*(
    field: int,
    value: enum,
    ProtoType: type ProtobufExt,
    skipDefault: static bool
): int =
  validateEnumType(typeof(value), ProtoType)
  computeFieldSize(field, int32(value.ord()), pint32, skipDefault)

func computeFieldSizePacked*(
    field: int,
    value: openArray[enum],
    ProtoType: type ProtobufExt
): int =
  validateEnumType(typeof(value[0]), ProtoType)
  computeFieldSizePacked(field, value, pint32)

proc writeField*(
    stream: OutputStream,
    field: int,
    value: enum,
    ProtoType: type ProtobufExt,
    skipDefault: static bool = false
) {.raises: [IOError].} =
  validateEnumType(typeof(value), ProtoType)
  writeField(stream, field, int32(value.ord()), pint32, skipDefault)

proc writeFieldPacked*(
    stream: OutputStream,
    field: int,
    value: openArray[enum],
    ProtoType: type ProtobufExt
) {.raises: [IOError].} =
  validateEnumType(typeof(value[0]), ProtoType)
  writeFieldPacked(stream, field, value, pint32)

proc readFieldInto*(
    stream: InputStream,
    value: var (enum),  # Nim 1.6 requires parens
    header: FieldHeader,
    ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  validateEnumType(typeof(value), ProtoType)
  if header.kind() == wireKind(pint32):
    let enumValue = stream.readValue(pint32)
    if checkedEnumAssign(value, enumValue.int32):
      true
    else:
      discard checkedEnumAssign(value, 0)
      false
  else:
    false

proc readFieldPackedInto*(
  stream: InputStream,
  value: var seq[enum],
  header: FieldHeader,
  ProtoType: type ProtobufExt
): bool {.raises: [SerializationError, IOError].} =
  validateEnumType(typeof(value[0]), ProtoType)
  var vals = default(seq[int32])
  if stream.readFieldPackedInto(vals, header, pint32):
    var v = default(typeof(value[0]))
    for val in vals:
      if checkedEnumAssign(v, val.int32):
        value.add v
    true
  else:
    false
