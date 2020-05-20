#Types/common data exported for use outside of this library.

import macros

import faststreams
import serialization/errors

import internal
export PInt, UInt, SInt, Fixed, pint, puint, sint, fixed

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

#We don't cast this back to a ProtobufWireType so it can prepended to a seq[bytes].
template wireType*(value: untyped): byte =
  when flatType(value) is (bool or VarIntWrapped):
    byte(VarInt) + (1 shl 3)
  elif flatType(value) is FixedWrapped:
    when sizeof(value) == 8:
      byte(Fixed64) + (1 shl 3)
    elif sizeof(value) == 4:
      byte(Fixed32) + (1 shl 3)
  else:
    byte(LengthDelimited) + (1 shl 3)
