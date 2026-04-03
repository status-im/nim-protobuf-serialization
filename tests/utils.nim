# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2
import stew/byteutils
import ../protobuf_serialization

proc roundtrip*[W, R](toWrite: W, value: R, expected: string) =
  let encoded = Protobuf.encode(toWrite)
  check:
    encoded.len == Protobuf.computeSize(toWrite)
    encoded == hexToSeqByte expected
    Protobuf.decode(encoded, R) == value

proc roundtrip*[R](value: R, expected: string) =
  let encoded = Protobuf.encode(value)
  check:
    encoded.len == Protobuf.computeSize(value)
    encoded == hexToSeqByte expected
    Protobuf.decode(encoded, R) == value
