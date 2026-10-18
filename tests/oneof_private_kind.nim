# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import ../protobuf_serialization

type
  Kind {.pure.} = enum
    notSet
    x
    y

  OneOfPrivateKind* {.proto3, oneof.} = object
    case kind*: Kind
    of Kind.notSet:
      discard
    of Kind.x:
      x* {.fieldNumber: 1, pint.}: int64
    of Kind.y:
      y* {.fieldNumber: 2, pint.}: int64

  ObjPrivateKind* {.proto3.} = object
    one* {.oneof.}: OneOfPrivateKind
