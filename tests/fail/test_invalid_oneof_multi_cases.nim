import ../../protobuf_serialization

type
  Kind1 {.pure.} = enum
    unset
    x
    y

  OneOf1 {.proto2, oneof.} = object
    case kind: Kind1
    of Kind1.unset:
      discard
    of Kind1.x:
      x {.fieldNumber: 1, pint.}: int64
    of Kind1.y:
      y {.fieldNumber: 2, pint.}: int64
    case kind2: Kind1
    of Kind1.unset:
      discard
    of Kind1.x:
      a {.fieldNumber: 3, pint.}: int64
    of Kind1.y:
      b {.fieldNumber: 4, pint.}: int64

  Obj1 {.proto2.} = object
    one {.oneof.}: OneOf1

discard Protobuf.encode(Obj1())
