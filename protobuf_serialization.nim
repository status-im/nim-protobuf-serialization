import
  serialization, protobuf__serialization/[reader, writer]

export
  serialization, reader, writer

serializationFormat Protobuf,
                    Reader = ProtobufReader,
                    Writer = ProtobufWriter,
                    PreferedOutput = seq[byte]

template supports*(_: type Protobuf, T: type): bool =
  true
