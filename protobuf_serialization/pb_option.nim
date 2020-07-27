{.warning[UnusedImport]: off}
import sets

type PBOption*[defaultValue: static[auto]] = object
  some: bool
  value: typeof(defaultValue)

proc isNone*(opt: PBOption): bool {.inline.} =
  not opt.some

proc isSome*(opt: PBOption): bool {.inline.} =
  opt.some

proc get*(opt: PBOption): auto =
  when opt.defaultValue is (object or seq or set or HashSet):
    {.fatal: "PBOption can not be used with objects or repeated types."}

  if opt.some:
    result = opt.value
  else:
    result = opt.defaultValue

proc pbSome*[T](optType: typedesc[T], value: auto): T {.inline.} =
  when value is (object or seq or set or HashSet):
    {.fatal: "PBOption can not be used with objects or repeated types."}

  T(
    some: true,
    value: value
  )

proc init*(opt: var PBOption, val: auto) =
  opt.some = true
  opt.value = val

converter toValue*(opt: PBOption): auto {.inline.} =
  opt.get()
