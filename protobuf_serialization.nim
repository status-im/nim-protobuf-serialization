import sets

import serialization
export serialization

import protobuf_serialization/[internal, types, reader, writer]
export types, reader, writer

import protobuf_serialization/files/type_generator
export protoToTypes, import_proto3

serializationFormat Protobuf,
                    Reader = ProtobufReader,
                    Writer = ProtobufWriter,
                    PreferedOutput = seq[byte]

func supportsInternal[T](ty: typedesc[T], handled: var HashSet[string]) {.compileTime.} =
  if handled.contains($T):
    return
  handled.incl($T)

  verifySerializable(T)
  var inst: T
  enumInstanceSerializedFields(inst, fieldName, fieldVar):
    discard fieldName
    when flatType(fieldVar) is (object or tuple):
      supportsInternal(flatType(fieldVar), handled)

func supportsCompileTime[T](_: typedesc[T]) =
  when flatType(T) is (object or tuple):
    var handled = initHashSet[string]()
    supportsInternal(flatType(T), handled)

func supports*[T](_: type Protobuf, ty: typedesc[T]): bool =
  static: supportsCompileTime(T)
  true
