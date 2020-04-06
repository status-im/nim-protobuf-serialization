import macros, strformat, typetraits, options
import faststreams

template sint32*() {.pragma.}
template sint64*() {.pragma.}
template sfixed32*() {.pragma.}
template sfixed64*() {.pragma.}
template fixed32*() {.pragma.}
template fixed64*() {.pragma.}
template float*() {.pragma.}
template double*() {.pragma.}

const
  MaxMessageSize* = 1'u shl 22

type
  ProtoBuffer* = object
    fieldNum: int
    outstream: OutputStreamVar

  ProtoWireType* = enum
    ## Protobuf's field types enum
    Varint, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  EncodingKind* = enum
    ekNormal, ekZigzag

  ProtoField*[T] = object
    ## Protobuf's message field representation object
    index*: int
    value*: T

  SomeSVarint* = int | int64 | int32 | int16 | int8 | enum
  SomeByte* = byte | bool | char | uint8
  SomeUVarint* = uint | uint64 | uint32 | uint16 | SomeByte
  SomeVarint* = SomeSVarint | SomeUVarint
  SomeLengthDelimited* = string | seq[SomeByte] | cstring
  SomeFixed64* = float64
  SomeFixed32* = float32
  SomeFixed* = SomeFixed32 | SomeFixed64

  AnyProtoType* = SomeVarint | SomeLengthDelimited | SomeFixed | object

  UnexpectedTypeError* = object of ValueError

proc newProtoBuffer*(): ProtoBuffer =
  ProtoBuffer(outstream: OutputStream.init(), fieldNum: 1)

proc output*(proto: ProtoBuffer): seq[byte] {.inline.} =
  proto.outstream.getOutput

template wireType(firstByte: byte): ProtoWireType =
  (firstByte and 0b111).ProtoWireType

template fieldNumber(firstByte: byte): int =
  ((firstByte shr 3) and 0b1111).int

template protoHeader*(fieldNum: int, wire: ProtoWireType): byte =
  ## Get protobuf's field header integer for ``index`` and ``wire``.
  ((cast[uint](fieldNum) shl 3) or cast[uint](wire)).byte

template increaseBytesRead(amount = 1) =
  ## Convenience template for increasing
  ## all of the counts
  mixin isSome
  bytesRead += amount
  outOffset += amount
  outBytesProcessed += amount
  if numBytesToRead.isSome():
    if (bytesRead > numBytesToRead.get()).unlikely:
      raise newException(Exception, &"Number of bytes read ({bytesRead}) exceeded bytes requested ({numBytesToRead})")

proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, value: T) {.inline.}
proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, fieldNum: int, value: T) {.inline.}
proc encodeField[T: not AnyProtoType](stream: OutputStreamVar, fieldNum: int, value: T) {.inline.}

proc put(stream: OutputStreamVar, value: SomeVarint) {.inline.} =
  when value is enum:
    var value = cast[type(ord(value))](value)
  elif value is bool or value is char:
    var value = cast[byte](value)
  else:
    var value = value

  when type(value) is SomeSVarint:
    # Encode using zigzag
    if value < type(value)(0):
      value = not(value shl type(value)(1))
    else:
      value = value shl type(value)(1)

  while value > type(value)(0b0111_1111):
    stream.append byte((value and 0b0111_1111) or 0b1000_0000)
    value = value shr 7
  stream.append byte(value and 0b1111_1111)

proc encodeField(stream: OutputStreamVar, fieldNum: int, value: SomeVarint) {.inline.} =
  stream.append protoHeader(fieldNum, Varint)
  stream.put(value)

proc put(stream: OutputStreamVar, value: SomeFixed) {.inline.} =
  when typeof(value) is SomeFixed64:
    var value = cast[int64](value)
  else:
    var value = cast[int32](value)

  for _ in 0 ..< sizeof(value):
    stream.append byte(value and 0b1111_1111)
    value = value shr 8

proc encodeField(stream: OutputStreamVar, fieldNum: int, value: SomeFixed64) {.inline.} =
  stream.append protoHeader(fieldNum, Fixed64)
  stream.put(value)

proc encodeField(stream: OutputStreamVar, fieldNum: int, value: SomeFixed32) {.inline.} =
  stream.append protoHeader(fieldNum, Fixed32)
  stream.put(value)

proc put(stream: OutputStreamVar, value: SomeLengthDelimited) {.inline.} =
  stream.put(len(value).uint)
  for b in value:
    stream.append byte(b)

proc encodeField(stream: OutputStreamVar, fieldNum: int, value: SomeLengthDelimited) {.inline.} =
  stream.append protoHeader(fieldNum, LengthDelimited)
  stream.put(value)

proc put(stream: OutputStreamVar, value: object) {.inline.}

proc encodeField(stream: OutputStreamVar, fieldNum: int, value: object) {.inline.} =
  # This is currently needed in order to get the size
  # of the output before adding it to the stream.
  # Maybe there is a better way to do this
  let objStream = OutputStream.init()
  objStream.put(value)

  let objOutput = objStream.getOutput()
  if objOutput.len > 0:
    stream.append protoHeader(fieldNum, LengthDelimited)
    stream.put(objOutput)

proc put(stream: OutputStreamVar, value: object) {.inline.} =
  var fieldNum = 1
  for _, val in value.fieldPairs:
    # Only store the value
    if default(type(val)) != val:
      stream.encodeField(fieldNum, val)
    inc fieldNum

proc encode*(protobuf: var ProtoBuffer, value: object) {.inline.} =
  protobuf.outstream.put(value)

proc encodeField*(protobuf: var ProtoBuffer, fieldNum: int, value: AnyProtoType) {.inline.} =
  protobuf.outstream.encodeField(fieldNum, value)

proc encodeField*(protobuf: var ProtoBuffer, value: AnyProtoType) {.inline.} =
  protobuf.encodeField(protobuf.fieldNum, value)
  inc protobuf.fieldNum

proc encodeField[T: not AnyProtoType](stream: OutputStreamVar, fieldNum: int, value: T) {.inline.} =
  stream.encodeField(fieldNum, value.toBytes)

proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, fieldNum: int, value: T) {.inline.} =
  protobuf.outstream.encodeField(fieldNum, value.toBytes)

proc encodeField*[T: not AnyProtoType](protobuf: var ProtoBuffer, value: T) {.inline.} =
  protobuf.encodeField(protobuf.fieldNum, value.toBytes)
  inc protobuf.fieldNum

proc get*[T: SomeFixed](
  bytes: var seq[byte],
  ty: typedesc[T],
  outOffset: var int,
  outBytesProcessed: var int,
  numBytesToRead = none(int)
): T {.inline.} =
  var bytesRead = 0
  when T is SomeFixed64:
    var value: int64
  else:
    var value: int32
  var shiftAmount = 0

  for _ in 0 ..< sizeof(T):
    value += type(value)(bytes[outOffset]) shl shiftAmount
    shiftAmount += 8
    increaseBytesRead()

  result = cast[T](value)

proc get[T: SomeVarint](
  bytes: var seq[byte],
  ty: typedesc[T],
  outOffset: var int,
  outBytesProcessed: var int,
  numBytesToRead = none(int)
): T {.inline.} =
  var bytesRead = 0
  # Only up to 128 bits supported by the spec
  when T is enum or T is char:
    var value: type(ord(result))
  elif T is bool:
    var value: byte
  else:
    var value: T

  var shiftAmount = 0
  while true:
    value += type(value)(bytes[outOffset] and 0b0111_1111) shl shiftAmount
    shiftAmount += 7
    if (bytes[outOffset] shr 7) == 0:
      break
    increaseBytesRead()

  increaseBytesRead()

  when ty is SomeSVarint:
    if (value and type(value)(1)) != type(value)(0):
      result = cast[T](not(value shr type(value)(1)))
    else:
      result = cast[T](value shr type(value)(1))
  else:
    result = T(value)

proc checkType[T: SomeVarint](tyByte: byte, ty: typedesc[T], offset: int) {.inline.} =
  let wireTy = wireType(tyByte)
  if wireTy != Varint:
    raise newException(UnexpectedTypeError, fmt"Not a varint at offset {offset}! Received a {wireTy}")

proc checkType[T: SomeFixed](tyByte: byte, ty: typedesc[T], offset: int) {.inline.} =
  let wireTy = wireType(tyByte)
  if wireTy notin {Fixed32, Fixed64}:
    raise newException(UnexpectedTypeError, fmt"Not a fixed32 or fixed64 at offset {offset}! Received a {wireTy}")

proc checkType[T: SomeLengthDelimited](tyByte: byte, ty: typedesc[T], offset: int) {.inline.} =
  let wireTy = wireType(tyByte)
  if wireTy != LengthDelimited:
    raise newException(UnexpectedTypeError, fmt"Not a length delimited value at offset {offset}! Received a {wireTy}")

proc checkType[T: object](tyByte: byte, ty: typedesc[T], offset: int) {.inline.} =
  let wireTy = wireType(tyByte)
  if wireTy != LengthDelimited:
    raise newException(UnexpectedTypeError, fmt"Not an object value at offset {offset}! Received a {wireTy}")

proc get*[T: SomeLengthDelimited](
  bytes: var seq[byte],
  ty: typedesc[T],
  outOffset: var int,
  outBytesProcessed: var int,
  numBytesToRead = none(int)
): T {.inline.} =
  var bytesRead = 0
  let decodedSize = bytes.get(uint, outOffset, outBytesProcessed, numBytesToRead)
  let length = decodedSize.int

  when T is string:
    result = newString(length)
    for i in outOffset ..< (outOffset + length):
      result[i - outOffset] = bytes[i].chr
  elif T is cstring:
    result = cast[cstring](bytes[outOffset ..< (outOffset + length)])
  else:
    result.setLen(length)
    for i in outOffset ..< (outOffset + length):
      result[i - outOffset] = type(result[0])(bytes[i])

  increaseBytesRead(length)

proc decodeField*[T: SomeFixed | SomeVarint | SomeLengthDelimited](
  bytes: var seq[byte],
  ty: typedesc[T],
  outOffset: var int,
  outBytesProcessed: var int,
  numBytesToRead = none(int)
): ProtoField[T] {.inline.} =
  var bytesRead = 0

  checkType(bytes[outOffset], ty, outOffset)

  result.index = fieldNumber(bytes[outOffset])
  increaseBytesRead()

  result.value = bytes.get(ty, outOffset, outBytesProcessed, numBytesToRead)

proc decodeField*[T: object](
  bytes: var seq[byte],
  ty: typedesc[T],
  outOffset: var int,
  outBytesProcessed: var int,
  numBytesToRead = none(int)
): ProtoField[T] {.inline.}

proc decodeField*[T: not AnyProtoType](
  bytes: var seq[byte],
  ty: typedesc[T],
  outOffset: var int,
  outBytesProcessed: var int,
  numBytesToRead = none(int)
): ProtoField[T] {.inline.} =

  var bytesRead = 0

  checkType(bytes[outOffset], seq[byte], outOffset)

  result.index = fieldNumber(bytes[outOffset])
  increaseBytesRead()

  var value = bytes.get(seq[byte], outOffset, outBytesProcessed, numBytesToRead)
  result.value = value.to(T)

macro setField(obj: typed, fieldNum: int, offset: int, bytesProcessed: int, bytesToRead: Option[int], value: untyped): untyped =
  let typeFields = obj.getTypeInst.getType

  let objFields = typeFields[2]
  expectKind objFields, nnkRecList

  result = newStmtList()

  let caseStmt = newNimNode(nnkCaseStmt)
  caseStmt.add(fieldNum)

  for i in 0 ..< len(objFields) - 1:
    let field = objFields[i]
    let ofBranch = newNimNode(nnkOfBranch)
    ofBranch.add(newLit(i+1))
    ofBranch.add(
      quote do:
        `obj`.`field` = decodeField(`value`, type(`obj`.`field`), `offset`, `bytesProcessed`, `bytesToRead`).value
    )
    caseStmt.add(ofBranch)

  let field = objFields[len(objFields) - 1]
  let elseBranch = newNimNode(nnkElse)
  elseBranch.add(
    nnkStmtList.newTree(
      quote do:
        `obj`.`field` = decodeField(`value`, type(`obj`.`field`), `offset`, `bytesProcessed`, `bytesToRead`).value
    )
  )
  caseStmt.add(elseBranch)
  result.add(caseStmt)

proc decodeField*[T: object](
  bytes: var seq[byte],
  ty: typedesc[T],
  outOffset: var int,
  outBytesProcessed: var int,
  numBytesToRead = none(int)
): ProtoField[T] {.inline.} =
  var bytesRead = 0

  checkType(bytes[outOffset], ty, outOffset)

  result.index = fieldNumber(bytes[outOffset])

  # read LD header
  # then read only amount of bytes needed
  increaseBytesRead()
  let decodedSize = bytes.get(uint, outOffset, outBytesProcessed, numBytesToRead)
  let bytesToRead = some(decodedSize.int)

  let oldOffset = outOffset
  while outOffset < oldOffset + bytesToRead.get():
    let fieldNum = fieldNumber(bytes[outOffset])
    setField(result.value, fieldNum, outOffset, outBytesProcessed, bytesToRead, bytes)

proc decode*[T: object](
  bytes: var seq[byte],
  ty: typedesc[T],
): T {.inline.} =
  var bytesRead = 0
  var offset = 0

  while offset < bytes.len - 1:
    let fieldNum = fieldNumber(bytes[offset])
    setField(result, fieldNum, offset, bytesRead, none(int), bytes)