import tables

import ../../protobuf_serialization

discard Protobuf.encode([(5, 5)].toTable())
