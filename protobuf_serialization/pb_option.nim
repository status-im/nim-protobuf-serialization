type PBOption*[T] = object
  some: bool
  value: T
  default: T

proc isNone*[T](opt: PBOption[T]): bool {.inline.} =
  not opt.some

proc isSome*[T](opt: PBOption[T]): bool {.inline.} =
  opt.some

proc get*[T](opt: PBOption[T]): T =
  if opt.some:
    result = opt.value
  else:
    result = opt.default

proc pbNone*[T](default: T): PBOption[T] {.inline.} =
  PBOption[T](default: default)

proc pbSome*[T](value: T): PBOption[T] {.inline.} =
  PBOption[T](some: true, value: value)

converter toValue*[T](opt: PBOption[T]): T {.inline.} =
  opt.get()

converter toOption*[T](value: T): PBOption[T] {.inline.} =
  pbSome(value)
