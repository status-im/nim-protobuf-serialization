#Variables needed by the Reader and Writer which should NOT be exported outside of this library.

import options
import macros

const
  VAR_INT_CONTINUATION_MASK*: byte = 0b1000_0000
  VAR_INT_VALUE_MASK*: byte = 0b0111_1111

type
  ProtobufWireType* = enum
    VarInt, Fixed64, LengthDelimited, StartGroup, EndGroup, Fixed32

  #Used to specify how to encode/decode primitives.
  #Despite being used outside of this library, all access is via templates.
  PIntWrapped32* = distinct int32
  PIntWrapped64* = distinct int64
  UIntWrapped32* = distinct uint32
  UIntWrapped64* = distinct uint64
  SIntWrapped32* = distinct int32
  SIntWrapped64* = distinct int64
  FixedWrapped32* = distinct uint32
  FixedWrapped64* = distinct uint64
  SFixedWrapped32* = distinct uint32
  SFixedWrapped64* = distinct uint64

  PIntWrapped* = PIntWrapped32 or PIntWrapped64
  UIntWrapped* = PIntWrapped32 or PIntWrapped64
  SIntWrapped* = SIntWrapped32 or SIntWrapped64
  Fixed32Wrapped* = FixedWrapped32 or SFixedWrapped32
  Fixed64Wrapped* = FixedWrapped64 or SFixedWrapped64

  #Number types which are platform-dependent and therefore unsafe.
  PlatformDependentTypes* = int or uint or float
  #Signed native types utilizing the VarInt/Fixed wire types.
  PureSIntegerTypes* = SomeSignedInt or enum

  #Every Signed Integer Type.
  SIntegerTypes* = PIntWrapped32 or PIntWrapped64 or
                   SIntWrapped32 or SIntWrapped64 or
                   SFixedWrapped32 or SFixedWrapped64 or
                   PureSIntegerTypes

  #Unsigned native types utilizing the VarInt/Fixed wire types.
  PureUIntegerTypes* = SomeUnsignedInt or char or bool
  #Every Unsigned Integer Type.
  UIntegerTypes* = UIntWrapped32 or UIntWrapped64 or
                   FixedWrapped32 or FixedWrapped64 or
                   PureUIntegerTypes

  #Every wrapped type that can be used with the VarInt wire type.
  WrappedVarIntTypes* = PIntWrapped32 or PIntWrapped64 or
                        UIntWrapped32 or UIntWrapped64 or
                        SIntWrapped32 or SIntWrapped64
  #Every type valid for the VarInt wire type.
  VarIntTypes* = SIntegerTypes or UIntegerTypes

  #Fixed types.
  WrappedFixedTypes* = FixedWrapped32 or FixedWrapped64 or
                       SFixedWrapped32 or SFixedWrapped64
  FixedTypes* = SFixedTypes or PureUIntegerTypes
  SFixedTypes* = PureSIntegerTypes or float32 or float64

  #Castable length delimited types.
  #These can be directly casted from a seq[byte] and do not require a custom converter.
  CastableLengthDelimitedTypes* = string or seq[char or byte or uint8 or bool]
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
      return quote do: true
  return quote do: false

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

template unwrap*[T](value: T): untyped =
  when T is (PIntWrapped32 or SIntWrapped32 or SFixedWrapped32):
    int32(value)
  elif T is (PIntWrapped64 or SIntWrapped64 or SFixedWrapped64):
    int64(value)
  elif T is (UIntWrapped32 or FixedWrapped32):
    uint32(value)
  elif T is (UIntWrapped64 or FixedWrapped64):
    uint64(value)
  else:
    {.fatal: "Tried to get the unwrapped value of a non-wrapped type. This should never happen.".}
