import ../../protobuf_serialization

type
  Kind1 {.pure.} = enum
    unset
    x
    y

  Kind2 {.pure.} = enum
    a
    b

  OneOf1 {.proto3, oneof.} = object
    case kind: Kind1
    of Kind1.unset:
      discard
    of Kind1.x:
      case kind2: Kind2
      of Kind2.a:
        a {.fieldNumber: 1, pint.}: int64
      of Kind2.b:
        b {.fieldNumber: 2, pint.}: int64
    of Kind1.y:
      y {.fieldNumber: 3, pint.}: int64

  Obj1 {.proto3.} = object
    one {.oneof.}: OneOf1

discard Protobuf.encode(Obj1())
