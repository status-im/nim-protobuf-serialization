# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.warning[UnusedImport]: off}

import ../protobuf_serialization

import
  test_all_types,
  test_bool,
  test_codec,
  test_fixed,
  test_groups,
  test_objects,
  test_pkg_results,
  test_empty,
  test_repeated,
  test_std_enums,
  test_protobuf2_semantics,
  test_thirty_three_fields,
  test_truncation,
  test_wire_type_mismatch,
  files/test_proto3
