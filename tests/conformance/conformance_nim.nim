import os
import ../../protobuf_serialization
import ../../protobuf_serialization/files/type_generator
import stew/byteutils
import_proto3 "../../conformance/conformance/conformance.proto"
import test_proto2
import test_proto3

proc readIntLE(): int32 =
  if stdin.readBuffer(addr(result), 4) != 4:
    raise newException(IOError, "readInt error")

proc writeIntLE(v: int32) =
  var value = v
  if stdout.writeBuffer(addr(value), 4) != 4:
    raise newException(IOError, "writeInt error")

template processPayload(payload, DecodeType): untyped =
  try:
    let x = Protobuf.decode(payload, TestAllTypesProto3)
    try:
      ConformanceResponse(protobuf_payload: Protobuf.encode(x))
    except ProtobufError as exc:
      ConformanceResponse(serialize_error: "serialize_error: " & exc.msg)
  except ProtobufGroupError as exc:
    ConformanceResponse(skipped: "skipped: " & exc.msg)
  except ProtobufError as exc:
    ConformanceResponse(parse_error: "parse_error: " & exc.msg)

proc doTest(request: ConformanceRequest): ConformanceResponse =
  if request.requested_output_format != WireFormat.PROTOBUF or
      request.protobuf_payload.len() == 0:
    ConformanceResponse(skipped: "skip not protobuf")
  elif request.message_type == "protobuf_test_messages.proto3.TestAllTypesProto3":
    processPayload(request.protobuf_payload, TestAllTypesProto3)
  elif request.message_type == "protobuf_test_messages.proto2.TestAllTypesProto2":
    processPayload(request.protobuf_payload, TestAllTypesProto2)
  else:
    ConformanceResponse(skipped: "skip unknown message type: " & request.message_type)

proc doTest(): bool =
  let length =
    try: readIntLE()
    except IOError: return false # EOF = done

  var serializedRequest = newSeq[byte](length)
  if stdin.readBuffer(addr(serializedRequest[0]), length) != length:
    raise newException(IOError, "IProtobuf./O error")

  let request = Protobuf.decode(serializedRequest, ConformanceRequest)
  let serializedResponse = Protobuf.encode(doTest(request))

  writeIntLE(serializedResponse.len().int32)

  stdout.write(string.fromBytes(serializedResponse))
  stdout.flushFile()
  true

try:
  while doTest():
    discard
except IOError as exc:
  stderr.writeLine(exc.msg)
