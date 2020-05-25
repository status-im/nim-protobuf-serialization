import ../../protobuf_serialization

#The field number must fix into 2^28.
#A signed int has the first bit unavailable, lowering the available bits to 2^31.
#Then encoding the wire type requires shifting left 3 bits.
#That leaves you with 2^27 for consistency on all platforms without slow extensions
type TooHighFieldNumber = object
  x {.fieldNumber: 268435457.}: bool

discard Protobuf.encode(TooHighFieldNumber())
