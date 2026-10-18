import ../../protobuf_serialization

type
  Kind1 {.pure.} = enum
    unset
    x
    y
    z

  OneOf1 {.proto3, oneof.} = object
    case kind: Kind1
    of Kind1.unset:
      discard
    of Kind1.x:
      x {.fieldNumber: 1, pint.}: int64
    of Kind1.y, Kind1.z:
      y {.fieldNumber: 2, pint.}: int64

  Obj1 {.proto3.} = object
    one {.oneof.}: OneOf1

discard Protobuf.encode(Obj1())
