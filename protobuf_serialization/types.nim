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
    template `name`*(value: untyped): untyped =
      when value is not `supported`:
        {.fatal: `err` & $type(value).}

      when value is type:
        when sizeof(value) == 8:
          `larger`
        else:
          `smaller`
      else:
        when sizeof(value) == 8:
          `larger`(value)
        else:
          `smaller`(value)

generateWrapperConstructors(PInt, SIntegerTypes, PIntWrapped32, PIntWrapped64, "PInt should only be used with a signed integer type.")
generateWrapperConstructors(UInt, UIntegerTypes, UIntWrapped32, UIntWrapped64, "UInt should only be used with an unsigned integer type.")
generateWrapperConstructors(SInt, SIntegerTypes, SIntWrapped32, SIntWrapped64, "SInt should only be used with a signed integer type.")
generateWrapperConstructors(Fixed, UIntegerTypes, FixedWrapped32, FixedWrapped64, "Fixed should only be used with an unsigned integer type.")
generateWrapperConstructors(SFixed, SIntegerTypes, SFixedWrapped32, SFixedWrapped64, "SFixed should only be used with a signed integer type.")

#Used to specify how to encode/decode fields in an object.
template pint*() {.pragma.}
template puint*() {.pragma.}
template sint*() {.pragma.}
template fixed*() {.pragma.}
template sfixed*() {.pragma.}
