import macros, strformat, options
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
        `obj`.`field` = decodeField[type(`obj`.`field`)](`value`, `offset`, `bytesProcessed`, `bytesToRead`).value
    )
    caseStmt.add(ofBranch)

  let field = objFields[len(objFields) - 1]
  let elseBranch = newNimNode(nnkElse)
  elseBranch.add(
    nnkStmtList.newTree(
      quote do:
        `obj`.`field` = decodeField[type(`obj`.`field`)](`value`, `offset`, `bytesProcessed`, `bytesToRead`).value
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

proc get*[T](
  bytes: var seq[byte],
  outOffset: var int,
  outBytesProcessed: var int,
  numBytesToRead = none(int)
): T =
  var bytesRead = 0

  when T is (enum or char):
    var value: type(ord(result))
  elif T is bool:
    var value: byte
  elif T is SomeVarint:
    var value: T
  elif T is SomeFixed64:
    var value: int64
  elif T is SomeFixed32:
    var value: int32
  elif T is SomeLengthDelimited:
    let
      decodedSize = get[uint](bytes, outOffset, outBytesProcessed, numBytesToRead)
      length = decodedSize.int
  else:
    var value: int32

  when T is SomeFixed:
    var shiftAmount = 0
    for _ in 0 ..< sizeof(T):
      value += type(value)(bytes[outOffset]) shl shiftAmount
      shiftAmount += 8
      increaseBytesRead()
  elif T is string:
    result = newString(length)
    for i in outOffset ..< (outOffset + length):
      result[i - outOffset] = bytes[i].chr
    increaseBytesRead(length)
  elif T is cstring:
    result = cast[cstring](bytes[outOffset ..< (outOffset + length)])
    increaseBytesRead(length)
  elif T is SomeLengthDelimited:
    result.setLen(length)
    for i in outOffset ..< (outOffset + length):
      result[i - outOffset] = type(result[0])(bytes[i])
    increaseBytesRead(length)
  elif T is SomeVarint:
    var shiftAmount = 0
    while true:
      value += type(value)(bytes[outOffset] and 0b0111_1111) shl shiftAmount
      shiftAmount += 7
      if (bytes[outOffset] shr 7) == 0:
        break
      increaseBytesRead()
    increaseBytesRead()
  else:
    {.fatal: "Attempted to get unsupported type.".}

  when T is SomeSVarint:
    if (value and type(value)(1)) != type(value)(0):
      result = cast[T](not(value shr type(value)(1)))
    else:
      result = cast[T](value shr type(value)(1))
  elif T is (SomeUVarint or SomeFixed):
    result = cast[T](value)

proc checkType[T](tyByte: byte, offset: int) =
  let wireTy = wireType(tyByte)
  when T is SomeVarint:
    if wireTy != Varint:
      raise newException(UnexpectedTypeError, fmt"Not a varint at offset {offset}! Received a {wireTy}")
  elif T is SomeFixed:
    if wireTy notin {Fixed32, Fixed64}:
      raise newException(UnexpectedTypeError, fmt"Not a fixed32 or fixed64 at offset {offset}! Received a {wireTy}")
  elif T is SomeLengthDelimited:
    if wireTy != LengthDelimited:
      raise newException(UnexpectedTypeError, fmt"Not a length delimited value at offset {offset}! Received a {wireTy}")
  else:
    if wireTy != LengthDelimited:
      raise newException(UnexpectedTypeError, fmt"Not an object value at offset {offset}! Received a {wireTy}")

proc decodeField*[T](
  bytes: var seq[byte],
  outOffset: var int,
  outBytesProcessed: var int,
  numBytesToRead = none(int)
): ProtoField[T] =
  var bytesRead = 0
  checkType[T](bytes[outOffset], outOffset)
  result.index = fieldNumber(bytes[outOffset])
  increaseBytesRead()

  when T is (SomeFixed or SomeVarint or SomeLengthDelimited):
    result.value = bytes.get[:T](outOffset, outBytesProcessed, numBytesToRead)
  elif T is object:
    let decodedSize = get[uint](bytes, outOffset, outBytesProcessed, numBytesToRead)
    let bytesToRead = some(decodedSize.int)

    let oldOffset = outOffset
    while outOffset < oldOffset + bytesToRead.get():
      let fieldNum: int = fieldNumber(bytes[outOffset])
      setField(result.value, fieldNum, outOffset, outBytesProcessed, bytesToRead, bytes)
  elif T is not AnyProtoType:
    var value = bytes.get[:seq[byte]](outOffset, outBytesProcessed, numBytesToRead)
    result.value = value.to[:T]()
  else:
    {.fatal: "Attempted to decode unsupported field.".}

proc decode*[T](bytes: var seq[byte]): T =
  var bytesRead = 0
  var offset = 0

  while offset < bytes.len - 1:
    let fieldNum = fieldNumber(bytes[offset])
    setField(result, fieldNum, offset, bytesRead, none(int), bytes)
