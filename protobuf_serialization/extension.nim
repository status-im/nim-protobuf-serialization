# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

import ./[types, format, codec]

export types, format, codec

template extensionDefaultsImpl(
    Format: type Protobuf,
    ExtType: type,
    defaultWriteSeq: bool,
    defaultReadSeq: bool,
    defaultSeq: bool,
    packed: bool
): untyped =
  ## Generate default procedures for the extension.
  ## - ``defaultSeq`` generates default ``seq[ExtType]``
  ##   writer and reader.
  ## - ``packed`` enables packed procedures overload support.

  func supportsPacked*(_: type ExtType, ProtoType: type ProtobufExt): bool =
    false

  func supportsPacked*(_: type seq[ExtType], ProtoType: type ProtobufExt): bool =
    packed

  when defaultWriteSeq or defaultSeq:
    func computeFieldSize*(
        field: int, 
        value: seq[ExtType],
        ProtoType: type ProtobufExt,
        skipDefault: static bool
    ): int =
      var dataSize = 0
      for i in 0 ..< value.len:
        dataSize += computeFieldSize(field, value[i], ProtoType, false)
      dataSize

    proc writeField*(
        stream: OutputStream,
        field: int,
        value: seq[ExtType],
        ProtoType: type ProtobufExt,
        skipDefault: static bool = false
    ) {.raises: [IOError].} =
      for i in 0 ..< value.len:
        stream.writeField(field, value[i], ProtoType, false)

  when defaultReadSeq or defaultSeq:
    proc readFieldInto*(
      stream: InputStream,
      value: var seq[ExtType],
      header: FieldHeader,
      ProtoType: type ProtobufExt
    ): bool {.raises: [SerializationError, IOError].} =
      var val = default(typeof(value[0]))
      if stream.readFieldInto(val, header, ProtoType):
        value.add move(val)
        true
      else:
        false

template extensionDefaults*(
    Format: type Protobuf,
    ExtType: type,
    PbType: type SomeProto,
    defaultWriteSeq = false,
    defaultReadSeq = false,
    defaultSeq = false
): untyped =
  ## Generate default procedures for the extension.
  ## - ``defaultSeq`` generates default ``seq[ExtType]``
  ##   writer and reader.

  extensionDefaultsImpl(
    Format,
    ExtType,
    defaultWriteSeq,
    defaultReadSeq,
    defaultSeq,
    PbType is SomePrimitive
  )

template extensionDefaults*(
    Format: type Protobuf,
    ExtType: type,
    defaultWriteSeq = false,
    defaultReadSeq = false,
    defaultSeq = false,
    packed = false
): untyped {.deprecated.} =
  extensionDefaultsImpl(
    Format,
    ExtType,
    defaultWriteSeq,
    defaultReadSeq,
    defaultSeq,
    packed
  )
