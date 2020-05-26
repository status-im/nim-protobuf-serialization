import macros

type
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
      elif value is not `supported`:
        {.fatal: `err`.}
      elif value is `exclusion`:
        {.fatal: "Tried to rewrap a wrapped type.".}

      when value is type:
        when value is `uTypes`:
          when sizeof(value) == 8:
            `uLarger`
          else:
            `uSmaller`
        elif value is `sTypes`:
          when sizeof(value) == 8:
            `sLarger`
          else:
            `sSmaller`
        #Used for Fixed floats.
        else:
          value
      else:
        when value is `uTypes`:
          when sizeof(value) == 8:
            `uLarger`(value)
          else:
            `uSmaller`(value)
        elif value is `sTypes`:
          when sizeof(value) == 8:
            `sLarger`(value)
          else:
            `sSmaller`(value)
        else:
          value
