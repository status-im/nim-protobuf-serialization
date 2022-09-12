import sets

import serialization
export serialization

import protobuf_serialization/[internal, types, reader, writer]
export types, reader, writer

serializationFormat Protobuf

Protobuf.setReader ProtobufReader
Protobuf.setWriter ProtobufWriter, PreferredOutput = seq[byte]

func supportsInternal[T](ty: typedesc[T], handled: var HashSet[string]) {.compileTime.} =
  if handled.contains($T):
    return
  handled.incl($T)

  verifySerializable(T)

func supportsCompileTime[T](_: typedesc[T]) =
  when flatType(default(T)) is (object or tuple):
    var handled = initHashSet[string]()
    supportsInternal(flatType(default(T)), handled)

func supports*[T](_: type Protobuf, ty: typedesc[T]): bool =
  # TODO return false when not supporting, instead of crashing compiler
  static: supportsCompileTime(T)
  true
