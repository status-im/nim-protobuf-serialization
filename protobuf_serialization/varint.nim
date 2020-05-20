import macros

import libp2p_varint

const
  VAR_INT_CONTINUATION_MASK*: byte = 0b1000_0000
  VAR_INT_VALUE_MASK*: byte = 0b0111_1111

type
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
  SFixedWrapped32* = distinct int32
  SFixedWrapped64* = distinct int64

  PIntWrapped* = PIntWrapped32 or PIntWrapped64
  UIntWrapped* = UIntWrapped32 or UIntWrapped64
  SIntWrapped* = SIntWrapped32 or SIntWrapped64
  VarIntWrapped* = PIntWrapped or UIntWrapped or SIntWrapped
  FixedWrapped* = FixedWrapped32 or FixedWrapped64 or
                  SFixedWrapped32 or SFixedWrapped64

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

  #Every type valid for the VarInt wire type.
  VarIntTypes* = SIntegerTypes or UIntegerTypes
  #Every type valid for the Fixed (32 or 64) wire type.
  FixedTypes* = FixedWrapped or
                PureUIntegerTypes or PureSIntegerTypes or
                float32 or float64

macro generateWrapperConstructors(
  name: untyped,
  supported: typed,
  smaller: typed,
  larger: typed,
  err: string
) =
  quote do:
    template `name`*(value: untyped): untyped =
      when value is not `supported`:
        {.fatal: `err`.}

      when value is type:
        when sizeof(value) == 8:
          `larger`
        else:
          `smaller`
      else:
        when sizeof(value) == 8:
          cast[`larger`](value)
        else:
          cast[`smaller`](value)

generateWrapperConstructors(PInt, SIntegerTypes, PIntWrapped32, PIntWrapped64, "PInt should only be used with a signed integer type.")
generateWrapperConstructors(UInt, UIntegerTypes, UIntWrapped32, UIntWrapped64, "UInt should only be used with an unsigned integer type.")
generateWrapperConstructors(SInt, SIntegerTypes, SIntWrapped32, SIntWrapped64, "SInt should only be used with a signed integer type.")

#Manually generate the Fixed template.
#This allows us to offer a single template for signed and unsigned fixed values.
template Fixed*(value: untyped): untyped =
  when value is not FixedTypes:
    {.fatal: "Fixed should only be used with a number.".}

  when value is type:
    when value is UIntegerTypes:
      when sizeof(value) == 8:
        FixedWrapped64
      else:
        FixedWrapped32
    else:
      when sizeof(value) == 8:
        SFixedWrapped64
      else:
        SFixedWrapped32
  else:
    when value is UIntegerTypes:
      when sizeof(value) == 8:
        FixedWrapped64(value)
      else:
        FixedWrapped32(value)
    else:
      when sizeof(value) == 8:
        cast[SFixedWrapped64](value)
      else:
        cast[SFixedWrapped32](value)

#Used to specify how to encode/decode fields in an object.
template pint*() {.pragma.}
template puint*() {.pragma.}
template sint*() {.pragma.}
template fixed*() {.pragma.}

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
