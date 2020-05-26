import tables

import ../../protobuf_serialization

discard Protobuf.encode(cstring("Testing string.")).toTable()
