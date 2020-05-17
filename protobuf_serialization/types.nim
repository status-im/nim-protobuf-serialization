#Types/common data exported for use outside of this library.

import macros

import faststreams
import serialization/errors

import internal

type
  ProtobufError* = object of SerializationError

  ProtobufWriter* = object
    stream*: OutputStream

func newProtobufWriter*(): ProtobufWriter {.inline, raises: [].} =
  ProtobufWriter(
    stream: memoryOutput()
  )

#This was originally called buffer, and retuned just the output.
#That said, getting the output purges the stream, and doesn't close it.
#Now it's called finish, as there's no reason to keep the stream open at that point.
#A singly function reduces API complexity/expectations on the user.
proc finish*(writer: ProtobufWriter): seq[byte] {.raises: [Defect, IOError].} =
  result = writer.stream.getOutput()
  writer.stream.close()

macro generateWrapperConstructors(
  name: untyped,
  supported: typed,
  smaller: typed,
  larger: typed,
  err: string
) =
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
          cast[`larger`](value)
        else:
          cast[`smaller`](value)

generateWrapperConstructors(PInt, SIntegerTypes, PIntWrapped32, PIntWrapped64, "PInt should only be used with a signed integer type.")
generateWrapperConstructors(UInt, UIntegerTypes, UIntWrapped32, UIntWrapped64, "UInt should only be used with an unsigned integer type.")
generateWrapperConstructors(SInt, SIntegerTypes, SIntWrapped32, SIntWrapped64, "SInt should only be used with a signed integer type.")
generateWrapperConstructors(Fixed, UIntegerTypes, FixedWrapped32, FixedWrapped64, "Fixed should only be used with an unsigned integer type.")
generateWrapperConstructors(SFixed, SFixedTypes, SFixedWrapped32, SFixedWrapped64, "SFixed should only be used with a signed integer or float type.")

#Used to specify how to encode/decode fields in an object.
template pint*() {.pragma.}
template puint*() {.pragma.}
template sint*() {.pragma.}
template fixed*() {.pragma.}
template sfixed*() {.pragma.}

#We don't cast this back to a ProtobufWireType so it can prepended to a seq[bytes].
template wireType*(value: untyped): byte =
  when value is WrappedVarIntTypes:
    byte(VarInt) + (1 shl 3)
  elif value is FixedTypes:
    when sizeof(value) == 8:
      byte(Fixed64) + (1 shl 3)
    elif sizeof(value) == 4:
      byte(Fixed32) + (1 shl 3)
  else:
    byte(LengthDelimited) + (1 shl 3)
