import os, sequtils, streams, endians, strutils
import protobuf_serialization
import protobuf_serialization/files/type_generator
import stew/byteutils
import_proto3 "conformance.proto", "/tmp/s1.nim"
import test_proto2
import test_proto3

var testCount = 0
let
  inputStream = newFileStream(stdin)
  outputStream = newFileStream(stdout)

proc readIntLE(s: Stream): int32 =
  let v = s.readInt32()
  var x: int32
  littleEndian32(addr(result), addr(v))
  bigEndian32(addr(x), addr(v))

proc writeIntLE(s: Stream, value: int32) =
  var value = value
  var buf: int32
  littleEndian32(addr(buf), addr(value))
  s.write(buf)

proc doTestIO(): bool = 
  let length = inputStream.readIntLE()
  var serializedRequestChar = newSeq[char](length)
  if stdin.readChars(serializedRequestChar) != length:
    raise newException(IOError, "IProtobuf./O error")
  let serializedRequest = serializedRequestChar.mapIt(it.ord().byte)
#  stderr.writeLine("=> ", length, " <", serializedRequest.foldl(if a == "": toHex(b) else: a & " " & toHex(b), ""), ">")
#  stderr.writeLine("pouf: ", serializedRequest)
  let request = Protobuf.decode(serializedRequest, ConformanceRequest)
#  stderr.writeLine("decoded => ", request)
  var response = ConformanceResponse()
  if request.requested_output_format != WireFormat.PROTOBUF or
      request.protobuf_payload.len() == 0:
    response.skipped = "skip not protobuf"
  else:
    try:
      #if request.message_type == "protobuf_test_messages.proto3.TestAllTypesProto3":
      if request.message_type == "protobuf_test_messages.proto3.TestAllTypesProto3":
        #stderr.writeLine("TYYYYYPE: ", type(request.protobuf_payload))
        stderr.writeLine("TADA")
        let xx: seq[byte] = request.protobuf_payload
        let payload = Protobuf.decode(xx, TestAllTypesProto3)
        response.protobuf_payload = Protobuf.encode(payload)
      else:
        response.skipped = "skip"
    except Exception as exc:
      response.runtime_error = exc.msg
  let serializedResponse = Protobuf.encode(response)
  #stderr.writeLine("Output response: " & $response, serializedResponse)
  outputStream.writeIntLE(serializedResponse.len().int32)
  outputStream.write(string.fromBytes(serializedResponse))
  outputStream.flush()
  testCount.inc()
  return true

while true:
  if not doTestIO():
    stderr.writeLine("conformance_nim: received EOF from test runner after ",
                     testCount, " tests, exiting")
    break
