import serialization
export serialization

import protobuf_serialization/[types, reader, writer]
export types, reader, writer

serializationFormat Protobuf,
                    Reader = ProtobufReader,
                    Writer = ProtobufWriter,
                    PreferedOutput = seq[byte]

template supports*(_: type Protobuf, T: type): bool =
  #Fake write it so every field is verified as serializable.
  #I tried importing verifySerializable and running that recursively yet couldn't get it working.
  let
    writer: ProtobufWriter.init(unsafeMemoryValue())
    inst: T
  discard writeValue(inst)
