import macros, strformat, typetraits, options
import faststreams
import types

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

template wireType(firstByte: byte): ProtoWireType =
  (firstByte and 0b111).ProtoWireType

template fieldNumber(firstByte: byte): int =
  ((firstByte shr 3) and 0b1111).int

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
