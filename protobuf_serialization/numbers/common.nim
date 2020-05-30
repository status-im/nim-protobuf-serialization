import macros

import serialization

type
  #Defined here so the number encoders/decoders have access.
  ProtobufError* = object of SerializationError

  ProtobufReadError* = object of ProtobufError
  ProtobufEOFError* = object of ProtobufReadError
  ProtobufMessageError* = object of ProtobufReadError

  #Signed native types.
  PureSIntegerTypes* = SomeSignedInt or enum
  #Unsigned native types.
  PureUIntegerTypes* = SomeUnsignedInt or char or bool
  #Every native type.
  PureTypes* = (PureSIntegerTypes or PureUIntegerTypes) and
               (not (byte or char or bool))

macro generateWrapper*(
  name: untyped,
  supported: typed,
  exclusion: typed,
  uTypes: typed,
  uLarger: typed,
  uSmaller: typed,
  sTypes: typed,
  sLarger: typed,
  sSmaller: typed,
  err: string
): untyped =
  let strLitName = newStrLitNode(name.strVal)
  quote do:
    template `name`*(value: untyped): untyped =
      when (value is (bool or byte or char)) and (`strLitName` != "PInt"):
        {.fatal: "Byte types are always PInt.".}

      #If this enum doesn't have negative values, considered it unsigned.
      when value is enum:
        when value is type:
          when ord(low(value)) < 0:
            type fauxType = int32
          else:
            type fauxType = uint32
        else:
          when ord(low(type(value))) < 0:
            type fauxType = int32
          else:
            type fauxType = uint32
      elif value is type:
        type fauxType = value
      else:
        type fauxType = type(value)

      when fauxType is not `supported`:
        {.fatal: `err`.}
      elif fauxType is `exclusion`:
        {.fatal: "Tried to rewrap a wrapped type.".}

      when value is type:
        when fauxType is `uTypes`:
          when sizeof(value) == 8:
            `uLarger`
          else:
            `uSmaller`
        elif fauxType is `sTypes`:
          when sizeof(value) == 8:
            `sLarger`
          else:
            `sSmaller`
        #Used for Fixed floats.
        else:
          value
      else:
        when fauxType is `uTypes`:
          when sizeof(value) == 8:
            `uLarger`(value)
          else:
            `uSmaller`(value)
        elif fauxType is `sTypes`:
          when sizeof(value) == 8:
            `sLarger`(value)
          else:
            `sSmaller`(value)
        else:
          value
