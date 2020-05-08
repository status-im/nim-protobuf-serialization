{.warning[UnusedImport]: off}

import ../protobuf_serialization

import
  test_varint,
  test_fixed,
  test_length_delimited,
  test_objects,
  test_empty

#Test internal types aren't exported.
when defined(PIntWrapped32):
  assert(false, "Internal types are being exported.")
