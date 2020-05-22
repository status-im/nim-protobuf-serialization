#Variables needed by the Reader and Writer which should NOT be exported outside of this library.

import options
import sets
import macros

import varint
export varint

type
  ProtobufWireType* = enum
    VarInt, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  #Number types which are platform-dependent and therefore unsafe.
  PlatformDependentTypes* = int or uint or float

  #Castable length delimited types.
  #These can be directly casted from a seq[byte] and do not require a custom converter.
  CastableLengthDelimitedTypes* = seq[char or byte or uint8 or bool]
  #This type is literally every other type.
  #Every other type is considered custom, due to the need for their own converters.
  #While cstring/array are built-ins, and therefore should have converters provided, but they still need converters.
  LengthDelimitedTypes* = not (VarIntTypes or FixedTypes)

proc getTypeChain(impure: NimNode): seq[NimNode] {.compileTime.} =
  var current = impure
  result = @[]
  while true:
    let
      impl = getTypeImpl(current)
      inst = getTypeInst(current)
    if (impl.kind == nnkBracketExpr) and (impl[0].strVal == "typeDesc"):
      current = impl[1]
    elif impl.kind == nnkRefTy:
      result.add(newNimNode(nnkRefTy))
      result[^1].add(inst)
      current = impl[0]
    elif inst.kind == nnkSym:
      if (result.len == 0) or (
        not (
          (result[^1].kind == nnkSym) and
          (result[^1].strVal == inst.strVal)
        )
      ):
        result.add(inst)
      break
    elif (inst.kind == nnkBracketExpr) and (inst[0].kind == nnkSym) and (inst[0].strVal == "Option"):
      current = inst[1]
      result.add(newNimNode(nnkBracketExpr))
    elif inst.kind == nnkBracketExpr:
      result.add(inst)
      break
    else:
      break

macro isPotentiallyNull*(impure: typed): bool =
  for ty in getTypeChain(impure):
    if (ty.kind == nnkRefTy) or (ty.kind == nnkBracketExpr):
      return newLit(true)
  result = newLit(false)

macro flatType*(impure: typed): untyped =
  getTypeChain(impure)[^1]

proc flatMapInternal[T, B](value: T, base: typedesc[B]): Option[B] =
  when value is Option:
    if value.isNone():
      none(base)
    else:
      flatMapInternal(value.get(), base)
  elif value is ref:
    if value.isNil:
      none(base)
    else:
      flatMapInternal(value[], base)
  else:
    some(value)

macro flatMap*(value: typed): untyped =
  let flattened = getTypeChain(value)[^1]
  quote do:
    flatMapInternal(`value`, type(`flattened`))

macro box*(variable: typed, value: typed): untyped =
  let chain = getTypeChain(variable)
  var wrap = value
  for l in countdown(high(chain) - 1, 0):
    if chain[l].kind == nnkRefTy:
      wrap = newBlockStmt(
        newStmtList(
          newNimNode(nnkVarSection).add(
            newNimNode(nnkIdentDefs).add(
              ident("newRef"),
              newNimNode(nnkEmpty),
              newNimNode(nnkCall).add(chain[l][0])
            )
          ),
          newNimNode(nnkAsgn).add(
            newNimNode(nnkBracketExpr).add(
              ident("newRef")
            ),
            wrap
          ),
          ident("newRef")
        )
      )
    elif chain[l].kind == nnkBracketExpr:
      wrap = newNimNode(nnkCall).add(ident("some"), wrap)

  quote do:
    `variable` = `wrap`

macro isStdlib*(ty: untyped): untyped =
  var underlying = ty.getTypeImpl()[1]
  if underlying.kind == nnkBracketExpr:
    discard
  elif underlying.kind == nnkSym:
    if (underlying.getTypeImpl().kind == nnkSym) or (underlying.getTypeImpl().kind == nnkBracketExpr):
      underlying = underlying.getTypeImpl()
  elif underlying.kind == nnkDistinctTy:
    underlying = underlying.getTypeImpl()[0]
  else:
    underlying = underlying.getTypeImpl()
  if underlying.kind != nnkBracketExpr:
    return newLit(underlying.strVal in [
      "string",
      "cstring"
    ].toHashSet())

  result = newLit(underlying[0].strVal in [
    "seq",
    "array",
    "set",
    "HashSet"
  ].toHashSet())

#[
This function exists because the optimal writer/reader calls toProtobuf/fromProtobuf whenever it's defined.
This file successfully returns a boolean of if the overload is defined.
That said, unfortunately, while the overload can be called from writer, it can't be passed.
I haven't found a way around this scoping issue, which is why all generics require a to/from Protobuf.
Hopefully, a workaround can be implemented which enables this macro to be used.

Concepts would also theoretically work, yet I couldn't get those working either.

macro has*(typeToCheckArg: untyped, overloadsArg: typed): untyped =
  var typeToCheck = getTypeImpl(typeToCheckArg)[1]
  var overloads = overloadsArg
  if overloads.len == 0:
    overloads = newNimNode(nnkClosedSymChoice).add(overloads)
  for overloadSym in overloads:
    var overload = getImpl(overloadSym)
    for argument in 1 ..< overload[3].len:
      if typeToCheck == overload[3][argument][1]:
        return newLit(true)
  result = newLit(false)
]#
