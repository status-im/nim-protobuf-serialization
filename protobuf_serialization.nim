import serialization
export serialization

import ./protobuf_serialization/[internal, types, reader, sizer, writer, format, extension]
export types, reader, sizer, writer, format, extension

Protobuf.setReader ProtobufReader
Protobuf.setWriter ProtobufWriter, PreferredOutput = seq[byte]

func supportsCompileTime[T](_: typedesc[T]) =
  when Protobuf.flatType(default(T)) is (object or tuple):
    verifySerializable(Protobuf.flatType(default(T)))

func supports*[T](_: type Protobuf, ty: typedesc[T]): bool =
  # TODO return false when not supporting, instead of crashing compiler
  static: supportsCompileTime(T)
  true

func computeSize*[T: object](_: type Protobuf, value: T): int =
  ## Return the encoded size of the given value
  computeObjectSize(value)
