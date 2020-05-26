#Types/common data exported for use outside of this library.

import faststreams
import serialization/errors

import internal
export PInt, SInt, LInt, Fixed, Float64, Float32
export pint, sint, lint, fixed, pfloat32, pfloat64, fieldNumber

type
  ProtobufError* = object of SerializationError

  ProtobufWriteError* = object of ProtobufError

  ProtobufReadError* = object of ProtobufError
  ProtobufEOFError* = object of ProtobufReadError
  ProtobufMessageError* = object of ProtobufReadError

  ProtobufWriter* = object
    stream*: OutputStream

  ProtobufReader* = object
    stream*: InputStream
    keyOverride*: Option[ProtobufKey]
    closeAfter*: bool

func init*(T: type ProtobufWriter, stream: OutputStream): T {.inline.} =
  T(stream: stream)

func init*(
  T: type ProtobufReader,
  stream: InputStream,
  key: Option[ProtobufKey] = none(ProtobufKey),
  closeAfter: bool = true
): T {.inline.} =
  T(stream: stream, keyOverride: key, closeAfter: closeAfter)

#This was originally called buffer, and retuned just the output.
#That said, getting the output purges the stream, and doesn't close it.
#Now it's called finish, as there's no reason to keep the stream open at that point.
#A singly function reduces API complexity/expectations on the user.
proc finish*(writer: ProtobufWriter): seq[byte] =
  result = writer.stream.getOutput()
  writer.stream.close()
