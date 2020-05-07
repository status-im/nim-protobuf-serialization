#Types/common data exported for use outside of this library.

import macros

import faststreams
import serialization/errors

import internal

type
  ProtobufError* = object of SerializationError

  ProtobufWriter* = object
    stream*: OutputStreamHandle

func newProtobufWriter*(): ProtobufWriter {.inline, raises: [].} =
  ProtobufWriter(
    stream: memoryOutput()
  )

func buffer*(writer: ProtobufWriter): seq[byte] {.inline, raises: [].} =
  writer.stream.s.getOutput()

macro generateWrapperConstructors(name: untyped, supported: typed,
                                  smaller: typed, larger: typed,
                                  err: string) =
  quote do:
    template `name`*[T](value: T): untyped =
      when T is not `supported`:
        {.fatal: `err`.}
      elif sizeof(T) == 8:
        `larger`(value)
      else:
        `smaller`(value)

    template `name`*(T: type): untyped =
      when T is not `supported`:
        {.fatal: `err`.}
      elif sizeof(T) == 8:
        `larger`
      else:
        `smaller`

generateWrapperConstructors(PInt, PureSIntegerTypes, PIntWrapped32, PIntWrapped64, "PInt should only be used with a signed integer type.")
generateWrapperConstructors(UInt, PureUIntegerTypes, UIntWrapped32, UIntWrapped64, "UInt should only be used with an unsigned integer type.")
generateWrapperConstructors(SInt, PureSIntegerTypes, SIntWrapped32, SIntWrapped64, "SInt should only be used with a signed integer type.")
generateWrapperConstructors(Fixed, PureUIntegerTypes, FixedWrapped32, FixedWrapped64, "Fixed should only be used with an unsigned integer type.")
generateWrapperConstructors(SFixed, PureSIntegerTypes, SFixedWrapped32, SFixedWrapped64, "SFixed should only be used with a signed integer type.")

#Used to specify how to encode/decode fields in an object.
template pint*() {.pragma.}
template puint*() {.pragma.}
template sint*() {.pragma.}
template fixed*() {.pragma.}
template sfixed*() {.pragma.}
