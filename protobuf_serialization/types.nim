#Types/common data exported for use outside of this library.

import
  faststreams,
  serialization/errors

export faststreams, errors

type
  ProtobufError* = object of SerializationError

  ProtobufReadError* = object of ProtobufError
  ProtobufEOFError* = object of ProtobufReadError
  ProtobufMessageError* = object of ProtobufReadError
  ProtobufValueError* = object of ProtobufReadError

  ProtobufFlags* = enum
    VarIntLengthPrefix

  ProtobufWriter* = object
    stream*: OutputStream
    flags*: set[ProtobufFlags]

  ProtobufReader* = ref object
    stream*: InputStream
    closeAfter*: bool

  PBOption*[defaultValue: static[auto]] = object
    some: bool
    value: typeof(defaultValue)

# Message type annotations
template proto2*() {.pragma.}
template proto3*() {.pragma.}

# Field annotations
template fieldNumber*(num: int) {.pragma.}
template required*() {.pragma.}
template packed*(v: bool) {.pragma.}
template pint*() {.pragma.} # encode as `intXX`
template sint*() {.pragma.} # encode as `sintXX`
template fixed*() {.pragma.} # encode as `fixedXX`

func init*(
  T: type ProtobufWriter,
  stream: OutputStream,
  flags: static set[ProtobufFlags] = {}
): T {.inline.} =
  T(stream: stream, flags: flags)

func init*(
  T: type ProtobufReader,
  stream: InputStream,
  # key: Option[ProtobufKey] = none(ProtobufKey),
  closeAfter: bool = true
): T {.inline.} =
  T(stream: stream, closeAfter: closeAfter)

#This was originally called buffer, and retuned just the output.
#That said, getting the output purges the stream, and doesn't close it.
#Now it's called finish, as there's no reason to keep the stream open at that point.
#A singly function reduces API complexity/expectations on the user.
proc finish*(writer: ProtobufWriter): seq[byte] =
  result = writer.stream.getOutput()
  writer.stream.close()

func isNone*(opt: PBOption): bool {.inline.} =
  not opt.some

func isSome*(opt: PBOption): bool {.inline.} =
  opt.some

func get*(opt: PBOption): auto =
  if opt.some:
    opt.value
  else:
    opt.defaultValue

template mget*(opt: var PBOption): untyped =
  opt.some = true
  opt.value

func pbSome*[T: PBOption](optType: typedesc[T], value: auto): T {.inline.} =
  T(
    some: true,
    value: value
  )

func init*(opt: var PBOption, val: auto) =
  opt.some = true
  opt.value = val

converter toValue*(opt: PBOption): auto {.inline.} =
  opt.get()
