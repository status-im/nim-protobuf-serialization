#Types/common data exported for use outside of this library.

{.push raises: [], gcsafe.}

import
  faststreams,
  serialization/errors

export faststreams, errors

type
  ProtobufError* = object of SerializationError
    ## Error raised when a protobuf decoding/encoding operation fails.
  ProtobufReadError* = object of ProtobufError
    ## Error raised when reading a protobuf message fails.
  ProtobufEOFError* = object of ProtobufReadError
    ## Error raised when unexpected end of input is encountered.
  ProtobufMessageError* = object of ProtobufReadError
    ## Error raised when a message structure is invalid.
  ProtobufValueError* = object of ProtobufReadError
    ## Error raised when a field value is invalid.
  ProtobufGroupError* = object of ProtobufValueError
    ## Error raised when a group (deprecated protobuf feature) is encountered.

  ProtobufFlags* = enum
    VarIntLengthPrefix
    ## Flags that control protobuf encoding behavior.

  ProtobufWriter* = object
    ## Writer for encoding Nim objects to protobuf format.
    stream*: OutputStream
    flags*: set[ProtobufFlags]

  ProtobufReader* = ref object
    ## Reader for decoding protobuf format to Nim objects.
    stream*: InputStream
    closeAfter*: bool

  PBOption*[defaultValue: static[auto]] = object
    ## Optional value type for protobuf fields. Allows distinguishing between
    ## "field not set" and "field set to default value". Only works with proto2.
    some: bool
    value: typeof(defaultValue)

  ProtobufExt*[FieldType; RootType; fieldName: static string] = object
    ## Type marker for protobuf extension types. Used internally for type extensions.

# Message type annotations
template proto2*() {.pragma.}
  ## Pragma to mark a type as using Protocol Buffers version 2 syntax.
  ## Proto2 supports required fields and explicit optional fields.

template proto3*() {.pragma.}
  ## Pragma to mark a type as using Protocol Buffers version 3 syntax.
  ## Proto3 has implicit default values and no required keyword.

# Field annotations
template fieldNumber*(num: int) {.pragma.}
  ## Pragma to assign a field number to a protobuf field. Required for all fields.
  ## Field numbers must be unique within a message and should never change.

template required*() {.pragma.}
  ## Pragma to mark a proto2 field as required. The field must be present in encoded messages.
  ## Only available in proto2; proto3 does not support required fields.

template packed*(v: bool) {.pragma.}
  ## Pragma to enable packed encoding for repeated fields. More efficient for scalar numeric types.
  ## All elements are encoded as a single length-delimited field instead of separate entries.

template pint*() {.pragma.}
  ## Pragma for "plain int" encoding using standard varint. Efficient for positive values,
  ## inefficient for negative values. Use for int32, int64, uint32, uint64.

template sint*() {.pragma.}
  ## Pragma for "signed int" encoding using zig-zag varint. Efficient for negative values.
  ## Use for int32, int64 when negative values are common.

template fixed*() {.pragma.}
  ## Pragma for fixed-width encoding. Always uses 4 or 8 bytes regardless of value.
  ## Use for large values or when predictable size matters. Use for fixed32, fixed64, sfixed32, sfixed64.

template ext*() {.pragma.}
  ## Pragma to mark a field as using a type extension. The field's type must have custom
  ## serialization logic defined via computeFieldSize, writeField, and readFieldInto.

template oneof*() {.pragma.}
  ## Pragma to mark a field as a oneof (union type). Only one field in the oneof can be set at a time.

func init*(
  T: type ProtobufWriter,
  stream: OutputStream,
  flags: static set[ProtobufFlags] = {}
): T {.inline.} =
  T(stream: stream, flags: flags)

func init*(
  T: type ProtobufReader,
  stream: InputStream,
  # key: Option[ProtobufKey] = none(ProtobufKey),
  closeAfter: bool = true
): T {.inline.} =
  T(stream: stream, closeAfter: closeAfter)

#This was originally called buffer, and retuned just the output.
#That said, getting the output purges the stream, and doesn't close it.
#Now it's called finish, as there's no reason to keep the stream open at that point.
#A singly function reduces API complexity/expectations on the user.
proc finish*(writer: ProtobufWriter): seq[byte] {.raises: [IOError].} =
  result = writer.stream.getOutput()
  writer.stream.close()

func isNone*(opt: PBOption): bool {.inline.} =
  ## Returns true if the optional value is not set.
  not opt.some

func isSome*(opt: PBOption): bool {.inline.} =
  ## Returns true if the optional value is set.
  opt.some

func get*(opt: PBOption): auto =
  ## Returns the value if set, otherwise returns the default value.
  if opt.some:
    opt.value
  else:
    opt.defaultValue

template mget*(opt: var PBOption): untyped =
  ## Returns a mutable reference to the value, marking it as set.
  ## Use this to modify the value in place.
  opt.some = true
  opt.value

template valueOr*(opt: PBOption, def: untyped): untyped =
  ## Returns the value if set, otherwise returns the provided default.
  ## Unlike `get`, this allows you to specify a custom default at call site.
  if opt.some:
    opt.value
  else:
    def

func pbSome*[T: PBOption](optType: typedesc[T], value: auto): T {.inline.} =
  ## Creates a PBOption with the given value marked as set.
  ## Use this to create optional values that are present.
  T(
    some: true,
    value: value
  )

template fixedDefault(T): untyped =
  when T is int64:
    0'i64
  elif T is int32:
    0'i32
  elif T is uint64:
    0'u64
  elif T is uint32:
    0'u32
  elif T is float64:
    0'f64
  elif T is float32:
    0'f32
  else:
    default(T)

template pbSome*(value: untyped): untyped =
  ## Creates a PBOption with the given value marked as set.
  ## The default value is inferred from the type of the value.
  ## Shorthand for `pbSome(PBOption[...], value)`.
  pbSome(PBOption[fixedDefault(typeof(value))], value)

template pbNone*(value: untyped): untyped =
  ## Creates a PBOption marked as not set (absent).
  ## The parameter specifies the default value type.
  PBOption[value]()

func init*(opt: var PBOption, val: auto) =
  opt.some = true
  opt.value = val

converter toValue*(opt: PBOption): auto {.inline.} =
  opt.get()
