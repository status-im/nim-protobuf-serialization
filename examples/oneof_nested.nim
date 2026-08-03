# ANCHOR: all
import protobuf_serialization

type
  Error {.proto3.} = object
    code {.fieldNumber: 1, pint.}: int32
    message {.fieldNumber: 2.}: string

  Success {.proto3.} = object
    data {.fieldNumber: 1.}: string

  ResultKind {.pure.} = enum
    notSet
    success
    error

  Result {.proto3, oneof.} = object
    case kind: ResultKind
    of ResultKind.notSet:
      discard
    of ResultKind.success:
      success {.fieldNumber: 10.}: Success
    of ResultKind.error:
      error {.fieldNumber: 11.}: Error

  Response {.proto3.} = object
    id {.fieldNumber: 1.}: string
    result {.oneof.}: Result

# Usage
let response = Response(
  id: "req-123",
  result: Result(
    kind: ResultKind.success,
    success: Success(data: "Operation completed")
  )
)

# Encode and decode
let encoded = Protobuf.encode(response)
let decoded = Protobuf.decode(encoded, Response)
assert decoded.id == "req-123"
assert decoded.result.kind == ResultKind.success
assert decoded.result.success.data == "Operation completed"

echo "Oneof with nested messages example passed!"
# ANCHOR_END: all