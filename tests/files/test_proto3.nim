import macros, os, strutils

import
  ../../protobuf_serialization,
  ../../protobuf_serialization/files/type_generator

macro test() =
  let
    parsed = protoToTypesInternal(currentSourcePath.parentDir / "test.proto3")
    vector = quote do:
      type
        TestEnum* {.pure, proto3.} = enum
          UNKNOWN = 0
          STARTED = 1

        Map_string_bytesEntry* {.proto3.} = object
          key* {.fieldNumber: 1.}: string
          value* {.fieldNumber: 2.}: seq[byte]

        TestMessage* {.proto3.} = object
          map_string_bytes* {.fieldNumber: 1.}: seq[Map_string_bytesEntry]

        Oneof_fieldKind* {.pure, proto3.} = enum
          notSet = 0
          oneof_uint32 = 1
          oneof_string = 2
          oneof_bytes = 3
          oneof_bool = 4
          oneof_uint64 = 5
          oneof_float = 6
          oneof_double = 7
          oneof_enum = 8
          oneof_any = 9

        Oneof_field* {.proto3, oneof.} = object
          case kind*: Oneof_fieldKind
          of Oneof_fieldKind.notSet:
            discard
          of Oneof_fieldKind.oneof_uint32:
            oneof_uint32* {.fieldNumber: 3, pint.}: uint32
          of Oneof_fieldKind.oneof_string:
            oneof_string* {.fieldNumber: 4.}: string
          of Oneof_fieldKind.oneof_bytes:
            oneof_bytes* {.fieldNumber: 5.}: seq[byte]
          of Oneof_fieldKind.oneof_bool:
            oneof_bool* {.fieldNumber: 6.}: bool
          of Oneof_fieldKind.oneof_uint64:
            oneof_uint64* {.fieldNumber: 7, pint.}: uint64
          of Oneof_fieldKind.oneof_float:
            oneof_float* {.fieldNumber: 8.}: float32
          of Oneof_fieldKind.oneof_double:
            oneof_double* {.fieldNumber: 9.}: float64
          of Oneof_fieldKind.oneof_enum:
            oneof_enum* {.fieldNumber: 10, ext.}: TestEnum
          of Oneof_fieldKind.oneof_any:
            oneof_any* {.fieldNumber: 11.}: seq[byte]

        TestOneOf* {.proto3.} = object
          pre* {.fieldNumber: 1, pint.}: int32
          oneof_field* {.oneof.}: Oneof_field
          post* {.fieldNumber: 2, pint.}: int32

        ErrorStatus* {.proto3.} = object
          message* {.fieldNumber: 1.}: string
          details* {.fieldNumber: 2.}: seq[seq[byte]]

        Result* {.proto3.} = object
          url* {.fieldNumber: 1.}: string
          title* {.fieldNumber: 2.}: string
          snippets* {.fieldNumber: 3.}: seq[string]

        SearchResponse* {.proto3.} = object
          results* {.fieldNumber: 1.}: seq[Result]

        Corpus* {.pure, proto3.} = enum
          UNIVERSAL = 0
          WEB = 1
          IMAGES = 2
          LOCAL = 3
          NEWS = 4
          PRODUCTS = 5
          VIDEO = 6

        SearchRequest* {.proto3.} = object
          query* {.fieldNumber: 1.}: string
          page_number* {.fieldNumber: 2, pint.}: int32
          result_per_page* {.fieldNumber: 3, pint.}: int32
          corpus* {.fieldNumber: 4, ext.}: Corpus

        Foo* {.proto3.} = object

  proc fixAst(ast: NimNode): NimNode =
    proc inspect(node: NimNode): NimNode =
      case node.kind
      of {nnkIdent, nnkSym}:
        # remove `gensymX
        ident(split($node, '`')[0])
      of nnkEmpty:
        node
      of nnkLiterals:
        node
      of nnkCall:
        var ret = newNimNode(nnkBracketExpr)
        for i in 1 ..< node.len:
          ret.add inspect(node[i])
        ret
      else:
        var rTree = node.kind.newTree()
        for child in node:
          rTree.add inspect(child)
        rTree

    inspect(ast)

  if parsed != vector.fixAst:
    raise newException(Exception, "Expected: " & repr(parsed))

test()

import_proto3 "test.proto3"
when not (
  Protobuf.supports(TestEnum) and
  Protobuf.supports(TestOneOf) and
  Protobuf.supports(ErrorStatus) and
  Protobuf.supports(Result) and
  Protobuf.supports(SearchResponse) and
  Protobuf.supports(Corpus) and
  Protobuf.supports(SearchRequest) and
  Protobuf.supports(Foo)
):
  {.fatal: "Parsed type wasn't supported for serialization.".}
