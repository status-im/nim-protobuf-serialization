import os
import ../../protobuf_serialization
import ../../protobuf_serialization/files/type_generator
import stew/byteutils
import_proto3 "conformance.proto"
import test_proto2
import test_proto3

proc readIntLE(): int32 =
  if stdin.readBuffer(addr(result), 4) != 4:
    raise newException(IOError, "readInt error")

proc writeIntLE(v: int32) =
  var value = v
  if stdout.writeBuffer(addr(value), 4) != 4:
    raise newException(IOError, "writeInt error")

while true:
  let length = readIntLE()

  var serializedRequest = newSeq[byte](length)
  if stdin.readBuffer(addr(serializedRequest[0]), length) != length:
    raise newException(IOError, "IProtobuf./O error")

  let request = Protobuf.decode(serializedRequest, ConformanceRequest)

  var response = ConformanceResponse()

  if request.requested_output_format != WireFormat.PROTOBUF or
      request.protobuf_payload.len() == 0:
    response.skipped = "skip not protobuf"
  else:
    try:
      if request.message_type == "protobuf_test_messages.proto3.TestAllTypesProto3":
        let x = Protobuf.decode(request.protobuf_payload, TestAllTypesProto3)
        response.protobuf_payload = Protobuf.encode(x)
      elif request.message_type == "protobuf_test_messages.proto2.TestAllTypesProto2":
        let x = Protobuf.decode(request.protobuf_payload, TestAllTypesProto2)
        response.protobuf_payload = Protobuf.encode(x)
      else:
        response.skipped = "skip unknown message type: " & request.message_type
    except Exception as exc:
      response.parse_error = exc.msg

  let serializedResponse = Protobuf.encode(response)

  writeIntLE(serializedResponse.len().int32)

  stdout.write(string.fromBytes(serializedResponse))
  stdout.flushFile()
