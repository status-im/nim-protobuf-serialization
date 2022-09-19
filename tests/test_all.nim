{.warning[UnusedImport]: off}

import ../protobuf_serialization

import
  test_bool,
  test_fixed,
  test_objects,
  test_empty,
  test_repeated,
  test_protobuf2_semantics,
  test_thirty_three_fields,
  files/test_proto3

#Test internal types aren't exported.
#There's just not a good place for this to go.
when defined(PIntWrapped32):
  assert(false, "Internal types are being exported.")
