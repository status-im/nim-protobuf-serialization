{.warning[UnusedImport]: off}

import ../protobuf_serialization

import
  test_varint,
  test_fixed,
  test_length_delimited,
  test_objects,
  test_empty,
  test_thirty_three_fields_dont_serialize

#Test internal types aren't exported.
#There's just not a good place for this to go.
when defined(PIntWrapped32):
  assert(false, "Internal types are being exported.")
