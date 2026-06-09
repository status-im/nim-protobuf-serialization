# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import 
  std/[macros, os, strutils],
  unittest2,
  ../protobuf_serialization,
  ../protobuf_serialization/files/type_generator

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

proc serviceHook(packages: seq[ProtoNode]): NimNode =
  result = newStmtList()
  # Add service proc definitions
  for p in packages:
    doAssert p.kind == ProtoType.Package
    for s in p.services:
      doAssert s.kind == ProtoType.Service
      for rpc in s.rpcs:
        doAssert rpc.kind == ProtoType.Rpc
        let name = ident(p.packageName & s.serviceName & rpc.rpcName)
        let param = ident(rpc.rpcParam)
        let returns = ident(rpc.rpcReturns)
        let req = ident("req")
        result.add quote do:
          proc `name`*(`req`: `param`): `returns`
  # Add service path consts
  for p in packages:
    doAssert p.kind == ProtoType.Package
    for s in p.services:
      doAssert s.kind == ProtoType.Service
      for rpc in s.rpcs:
        doAssert rpc.kind == ProtoType.Rpc
        let rpcPathName = ident(p.packageName & s.serviceName & rpc.rpcName & "Path")
        let rpcPathVal = if p.packageName != "":
          newStrLitNode(p.packageName & "." & s.serviceName & "/" & rpc.rpcName)
        else:
          newStrLitNode(s.serviceName & "/" & rpc.rpcName)
        result.add quote do:
          const `rpcPathName`* = `rpcPathVal`

proc checkProtoFile(protoFile: string, expected: NimNode, protoHook: ProtoHook = nil) =
  let gened = protoToTypesImpl(currentSourcePath.parentDir / protoFile, protoHook = protoHook)
  if gened != expected.fixAst:
    checkpoint("FAILED: Got: \n" & repr(gened) & "\nExpected: " & repr(expected.fixAst))
    fail()

suite "Test proto file import":
  staticTest "test_proto_file_test.proto3 file":
    let expected = quote do:
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

    checkProtoFile("test_proto_file_test.proto3", expected)

  staticTest "test_proto_file_services.proto3 file":
    let expected = quote do:
      type
        HealthResponse* {.proto3.} = object
          status* {.fieldNumber: 1, pint.}: int32

        HealthRequest* {.proto3.} = object
          timeout* {.fieldNumber: 1, pint.}: int32

        DiscoverResponse* {.proto3.} = object
          url* {.fieldNumber: 1.}: string

        DiscoverRequest* {.proto3.} = object
          query* {.fieldNumber: 1.}: string

        SearchResponse* {.proto3.} = object
          url* {.fieldNumber: 1.}: string

        SearchRequest* {.proto3.} = object
          query* {.fieldNumber: 1.}: string

      proc testSearchServiceSearch*(req: SearchRequest): SearchResponse
      proc testSearchServiceHealth*(req: HealthRequest): HealthResponse
      proc testDiscoverServiceDiscover*(req: DiscoverRequest): DiscoverResponse
      proc testDiscoverServiceHealth*(req: HealthRequest): HealthResponse

      const testSearchServiceSearchPath* = "test.SearchService/Search"
      const testSearchServiceHealthPath* = "test.SearchService/Health"
      const testDiscoverServiceDiscoverPath* = "test.DiscoverService/Discover"
      const testDiscoverServiceHealthPath* = "test.DiscoverService/Health"

    checkProtoFile("test_proto_file_services.proto3", expected, protoHook = serviceHook)

import_proto3 "test_proto_file_test.proto3"

suite "Test proto generated types":
  test "response object":
    check(
      Protobuf.supports(TestEnum) and
      Protobuf.supports(TestOneOf) and
      Protobuf.supports(ErrorStatus) and
      Protobuf.supports(Result) and
      Protobuf.supports(SearchResponse) and
      Protobuf.supports(Corpus) and
      Protobuf.supports(SearchRequest) and
      Protobuf.supports(Foo)
    )
