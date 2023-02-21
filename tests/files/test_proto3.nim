import macros, os

import strutils

import ../../protobuf_serialization
import ../../protobuf_serialization/files/type_generator

macro test() =
  var
    parsed: NimNode = protoToTypesInternal(currentSourcePath.parentDir / "test.proto3")
    vector: NimNode = quote do:
      type
        TestEnum* {.pure, proto3.} = enum
          UNKNOWN = 0
          STARTED = 1

        ErrorStatus* {.proto3.} = object
          details* {.fieldNumber: 2.}: seq[seq[byte]]
          message* {.fieldNumber: 1.}: string

        SearchResponse* {.proto3.} = object
          results* {.fieldNumber: 1.}: seq[Result]

        Result* {.proto3.} = object
          snippets* {.fieldNumber: 3.}: seq[string]
          title* {.fieldNumber: 2.}: string
          url* {.fieldNumber: 1.}: string

        SearchRequest* {.proto3.} = object
          corpus* {.fieldNumber: 4.}: Corpus
          result_per_page* {.fieldNumber: 3, pint.}: int32
          page_number* {.fieldNumber: 2, pint.}: int32
          query* {.fieldNumber: 1.}: string

        Corpus* {.pure, proto3.} = enum
          UNIVERSAL = 0
          WEB = 1
          IMAGES = 2
          LOCAL = 3
          NEWS = 4
          PRODUCTS = 5
          VIDEO = 6

        Foo* {.proto3.} = object

  proc convertFromSym(parent: NimNode, i: int) =
    if parent[i].kind == nnkSym:
      parent[i] = ident(parent[i].strVal)
    elif parent[i].kind == nnkIdent:
      parent[i] = ident(parent[i].strVal.split('`')[0])
    elif parent[i].kind == nnkCall:
      parent[i] = newNimNode(nnkBracketExpr).add(
        ident(parent[i][1].strVal),
        parent[i][2]
      )
      if parent[i][1].kind == nnkSym:
        parent[i][1] = ident(parent[i][1].strVal)
    for c1 in 0 ..< parent.len:
      for c2 in 0 ..< parent[c1].len:
        convertFromSym(parent[c1], c2)
  for c in 0 ..< vector.len:
    convertFromSym(vector, c)

  if not (parsed == vector):
    raise newException(Exception, "")

test()

import_proto3 "test.proto3"
when not (
  Protobuf.supports(TestEnum) and
  Protobuf.supports(ErrorStatus) and
  Protobuf.supports(Result) and
  Protobuf.supports(SearchResponse) and
  Protobuf.supports(Corpus) and
  Protobuf.supports(SearchRequest) and
  Protobuf.supports(Foo)
):
  {.fatal: "Parsed type wasn't supported for serialization.".}
