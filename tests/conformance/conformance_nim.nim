# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/os,
  stew/byteutils,
  ../../protobuf_serialization,
  ../../protobuf_serialization/std/enums,
  ../../protobuf_serialization/files/type_generator

import_proto3 "../../conformance/conformance/conformance.proto"

import
  ./test_proto2,
  ./test_proto3

proc readIntLE(): int32 =
  if stdin.readBuffer(addr(result), 4) != 4:
    raise newException(IOError, "readInt error")

proc writeIntLE(v: int32) =
  var value = v
  if stdout.writeBuffer(addr(value), 4) != 4:
    raise newException(IOError, "writeInt error")

template processPayload(payload, DecodeType): untyped =
  try:
    let x = Protobuf.decode(payload, DecodeType)
    try:
      ConformanceResponse(protobuf_payload: Protobuf.encode(x))
    except ProtobufError as exc:
      ConformanceResponse(serialize_error: "serialize_error: " & exc.msg)
  #except ProtobufGroupError as exc:
  #  ConformanceResponse(skipped: "skipped: " & exc.msg)
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
  let response = doTest(request)
  let serializedResponse = if response == default(ConformanceResponse):
    # XXX: remove once oneof is supported;
    #      this is field 3 set to an empty seq
    "1a00".hexToSeqByte
  else:
    Protobuf.encode(response)

  writeIntLE(serializedResponse.len().int32)

  stdout.write(string.fromBytes(serializedResponse))
  stdout.flushFile()
  true

try:
  while doTest():
    discard
except IOError as exc:
  stderr.writeLine(exc.msg)
