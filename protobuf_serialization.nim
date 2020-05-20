import serialization
export serialization

import protobuf_serialization/[types, reader, writer]
export types, reader, writer

serializationFormat Protobuf,
                    Reader = ProtobufReader,
                    Writer = ProtobufWriter,
                    PreferedOutput = seq[byte]

template supports*(_: type Protobuf, T: type): bool =
  true
