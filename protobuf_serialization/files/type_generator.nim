# nim-protobuf-serialization
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[os, algorithm, strutils, tables, sets, macros],
  stew/shims/macros as stewmacros,
  ./[decldef, proto_parser]

export decldef, tables

type
  ProtoHook* = proc (packages: seq[ProtoNode]): NimNode {.raises: [], gcsafe.}

# https://protobuf.dev/programming-guides/proto3/#scalar
proc getTypeAndPragma(strVal: string): (NimNode, NimNode) =
  result[0] = ident(strVal.split('.')[^1]) # TODO: Find a better way to handle namespaces
  case strVal:
    of "float":
      result[0] = ident("float32")
    of "double":
      result[0] = ident("float64")
    of "int32":
      result[1] = ident("pint")
    of "int64":
      result[1] = ident("pint")
    of "uint32":
      result[1] = ident("pint")
    of "uint64":
      result[1] = ident("pint")
    of "sint32":
      result[1] = ident("sint")
      result[0] = ident("int32")
    of "sint64":
      result[1] = ident("sint")
      result[0] = ident("int64")
    of "fixed32":
      result[1] = ident("fixed")
      result[0] = ident("uint32")
    of "fixed64":
      result[1] = ident("fixed")
      result[0] = ident("uint64")
    of "sfixed32":
      result[1] = ident("fixed")
      result[0] = ident("int32")
    of "sfixed64":
      result[1] = ident("fixed")
      result[0] = ident("int64")
    of "bytes":
      result[0] = newNimNode(nnkBracketExpr).add(
        ident("seq"),
        ident("byte")
      )

proc parseDefault(val: string, ptype: NimNode): NimNode =
  case ptype.kind
  of nnkBracketExpr:
    var res = newSeq[byte]()
    for c in val:
      res.add c.byte
    newLitFixed(res)
  of nnkIdent:
    let v = case $ptype
    of "int32": val & "'i32"
    of "int64": val & "'i64"
    of "uint32": val & "'u32"
    of "uint64": val & "'u64"
    of "float32": val & "'f32"
    of "float64": val & "'f64"
    of "string": "\"" & val & "\""
    of "bool": val
    else: raiseAssert "unsupported proto type default: " & $ptype
    parseExpr(v)
  else:
    raiseAssert "unexpected nnk: " & $ptype.kind

proc getMessage(name: string, messages: seq[ProtoNode]): ProtoNode =
  for msg in messages:
    if msg.kind == ProtoType.Extend:
      continue
    if name == msg.messageName:
      return msg
    let res = name.getMessage(msg.nested)
    if not res.isNil():
      return res
  return nil

proc isNested(base: string, currentName: string, messages: seq[ProtoNode], seen: var seq[ProtoNode]): bool =
  let msg = currentName.getMessage(messages)
  if msg.isNil():
    return false
  if msg in seen:
    return false
  seen.add msg
  for field in msg.fields:
    if field.kind == ProtoType.Field:
      if field.presence == Repeated: continue
      if base == field.protoType or base.isNested(field.protoType, messages, seen):
        return true
    elif field.kind == ProtoType.Oneof:
      for f in field.oneof:
        if f.presence == Repeated: continue
        if base == f.protoType or base.isNested(f.protoType, messages, seen):
          return true

proc isNested(base: string, currentName: string, messages: seq[ProtoNode]): bool =
  # XXX use a set
  var seen = default(seq[ProtoNode])
  isNested(base, currentName, messages, seen)

proc addMessage(messages: var seq[ProtoNode], msg: ProtoNode) =
  if msg.kind == ProtoType.Extend:
    return
  doAssert msg.kind == ProtoType.Message, $msg.kind
  for nestee in msg.nested:
    addMessage(messages, nestee)
  messages.add(msg)

proc protoToTypesInternalImpl(filepath: string, isProto3 = true, protoHook: ProtoHook = nil): NimNode {.compileTime.} =
  var
    packages = parseProtobuf(filepath).packages
    messages = newSeq[ProtoNode]()
    enums = newSeq[ProtoNode]()
    oneofs = newSeq[ProtoNode]()
    maps = newSeq[ProtoNode]()
    enumNames = initHashSet[string]()
    typeSection = newNimNode(nnkTypeSection)

  # TODO: nodes ordered by enums, maps, oneofs, messages to workaround https://github.com/nim-lang/Nim/issues/25651
  # TODO: order in topological sort / message dependency order
  for pkg in packages:
    for pbEnum in pkg.packageEnums:
      doAssert pbEnum.kind == ProtoType.Enum
      enums.add(pbEnum)
    for msg in pkg.messages:
      if msg.kind == ProtoType.Message:
        messages.addMessage msg
  for msg in messages:
    for pbEnum in msg.definedEnums:
      doAssert pbEnum.kind == ProtoType.Enum
      enums.add(pbEnum)
    for field in msg.fields:
      if field.kind == ProtoType.Oneof:
        # Oneof does not allow: map, repeated, optional
        let field = ProtoNode(
          kind: ProtoType.Oneof,
          oneofName: msg.messageName & field.oneofName.capitalizeAscii(),
          oneof: field.oneof
        )
        var enumVals = @[ProtoNode(kind: ProtoType.EnumVal, fieldName: "notSet", num: 0)]
        for i, f in field.oneof.pairs():
          doAssert f.kind == ProtoType.Field, $f.kind
          enumVals.add ProtoNode(kind: ProtoType.EnumVal, fieldName: f.name, num: i + 1)
        oneofs.add ProtoNode(
          kind: ProtoType.Enum,
          enumName: field.oneofName & "Kind",
          values: enumVals
        )
        oneofs.add(field)
      elif field.kind == ProtoType.Field and field.protoType.startsWith("map<"):
        let matches = field.protoType.split({'<', '>', ','})
        let entryFields = @[
          ProtoNode(kind: ProtoType.Field, number: 1, protoType: matches[1], name: "key"),
          ProtoNode(kind: ProtoType.Field, number: 2, protoType: matches[2], name: "value")
        ]
        maps.add ProtoNode(
          kind: Message,
          messageName: field.name.capitalizeAscii() & "Entry",
          fields: entryFields)

  for pbEnum in enums:
    enumNames.incl pbEnum.enumName

  for node in enums & maps & oneofs & messages:
    var name: string
    var value: NimNode
    case node.kind
    of ProtoType.Enum:
      # TODO: allow_alias
      var alreadySeen: seq[int] = @[]
      name = node.enumName
      value = newNimNode(nnkEnumTy).add(newEmptyNode())
      for enumField in node.values.sortedByIt(it.num):
        if enumField.num in alreadySeen:
          continue
        alreadySeen.add(enumField.num)
        value.add(newNimNode(nnkEnumFieldDef).add(
          ident(enumField.fieldName),
          newIntLitNode(enumField.num)
        ))
    of ProtoType.Oneof:
      name = node.oneofName
      let caseKind = ident(name & "Kind")
      let caseOf = newNimNode(nnkRecCase).add(
        newIdentDefs(newNimNode(nnkPostfix).add(ident("*"), ident("kind")), caseKind),
        newNimNode(nnkOfBranch).add(
          newDotExpr(caseKind, ident"notSet"),
          newNimNode(nnkRecList).add(newNilLit())
        )
      )
      for field in node.oneof:
        doAssert field.kind == ProtoType.Field, $field.kind
        let (typ, pragma) = if field.protoType == "google.protobuf.Any":
          getTypeAndPragma("bytes")
        else:
          getTypeAndPragma(field.protoType)
        var pragmas = default(seq[NimNode])
        if not pragma.isNil():
          pragmas.add pragma
        if field.protoType.split('.')[^1] in enumNames:
          pragmas.add ident"ext"
        caseOf.add(
          newNimNode(nnkOfBranch).add(
            newDotExpr(caseKind, ident(field.name)),
            newNimNode(nnkRecList).add(newIdentDefs(
              newNimNode(nnkPragmaExpr).add(
                newNimNode(nnkPostfix).add(ident("*"), ident(field.name)),
                newNimNode(nnkPragma).add(
                  newNimNode(nnkExprColonExpr).add(ident("fieldNumber"), newIntLitNode(field.number))
                ).add(pragmas)
              ),
              typ
            ))
          )
        )
      value = newNimNode(nnkObjectTy).add(
        newEmptyNode(),
        newEmptyNode(),
        newNimNode(nnkRecList).add(caseOf)
      )
    of ProtoType.Message:
      name = node.messageName
      value = newNimNode(nnkObjectTy).add(
        newEmptyNode(),
        newEmptyNode(),
        newNimNode(nnkRecList)
      )
      for field in node.fields:
        case field.kind
        of ProtoType.Oneof:
          value[2].add(newNimNode(nnkIdentDefs).add(
            newNimNode(nnkPragmaExpr).add(
              newNimNode(nnkPostfix).add(
                ident("*"),
                ident(field.oneofName)
              ),
              newNimNode(nnkPragma).add(ident("oneof"))
            ),
            ident(node.messageName & field.oneofName.capitalizeAscii()),
            newEmptyNode()
          ))
        of ProtoType.Field:
          value[2].add(newNimNode(nnkIdentDefs).add(
            newNimNode(nnkPragmaExpr).add(
              newNimNode(nnkPostfix).add(
                ident("*"),
                ident(field.name)
              ),
              newNimNode(nnkPragma).add(
                newNimNode(nnkExprColonExpr).add(
                  ident("fieldNumber"),
                  newIntLitNode(field.number)
                )
              )
            ),
            ident(if field.protoType == "google.protobuf.Any": "bytes" else: field.protoType),
            newEmptyNode()
          ))

          var isReference = false
          for parsed in packages:
            if node.messageName.isNested(field.protoType, parsed.messages):
              isReference = true
              break

          if value[2][^1][1].strVal.startsWith("map<"):
            value[2][^1][1] = newNimNode(nnkBracketExpr).add(
              ident("seq"), ident(field.name.capitalizeAscii() & "Entry")
            )
          else:
            let (typ, pragma) = getTypeAndPragma(value[2][^1][1].strVal)
            value[2][^1][1] = typ
            if not pragma.isNil():
              value[2][^1][0][1].add(pragma)

          # XXX fix namespaces
          if field.protoType.split('.')[^1] in enumNames:
            value[2][^1][0][1].add ident"ext"

          if field.presence == Optional and not isProto3:
            var optDefault = ""
            for opt in field.options:
              if opt.optName == "default":
                optDefault = opt.optVal
            let typ = value[2][^1][1]
            let innerTyp = if optDefault.len > 0:
              parseDefault(optDefault, typ)
            else:
              quote do: default(`typ`)
            value[2][^1][1] = quote do: PBOption[`innerTyp`]

          for opt in field.options:
            if opt.optName == "packed" and opt.optVal in ["true", "false"]:
              value[2][^1][0][1].add(
                newNimNode(nnkExprColonExpr).add(
                  ident(opt.optName),
                  newLitFixed(opt.optVal == "true")
                )
              )

          if field.presence == Repeated:
            value[2][^1][1] = newNimNode(nnkBracketExpr).add(
              ident("seq"),
              value[2][^1][1]
            )
          elif isReference:
            value[2][^1][1] = newNimNode(nnkRefTy).add(value[2][^1][1])
        else:
          raiseAssert "Unexpected proto type: " & $field.kind

      # Empty message
      if value[2].len == 0:
        value[2] = newEmptyNode()
    else:
      raiseAssert "Unhandled proto node " & $node.kind

    let protoVer = if isProto3:
      "proto3"
    else:
      "proto2"

    typeSection.add(
      newNimNode(nnkTypeDef).add(
        newNimNode(nnkPragmaExpr).add(
          newNimNode(nnkPostfix).add(ident("*"), ident(name)),
          if node.kind == ProtoType.Enum:
            newNimNode(nnkPragma).add(ident("pure"), ident(protoVer))
          elif node.kind == ProtoType.Oneof:
            newNimNode(nnkPragma).add(ident(protoVer), ident("oneof"))
          else:
            newNimNode(nnkPragma).add(ident(protoVer))
        ),
        newEmptyNode(),
        value
      )
    )
  result = if protoHook != nil:
    let n = protoHook(packages)
    if n.kind == nnkStmtList:
      var ret = newStmtList().add(typeSection)
      for child in n:
        ret.add child
      ret
    else:
      newStmtList().add(typeSection).add(n)
  else:
    typeSection
  when defined(LogGeneratedTypes):
    result.storeMacroResult(true)

proc protoToTypesImpl*(filepath: string, protoHook: ProtoHook = nil): NimNode {.compileTime.} =
  protoToTypesInternalImpl(filepath, protoHook = protoHook)

proc protoToTypesInternal*(filepath: string): NimNode {.compileTime, deprecated: "use protoToTypesImpl".} =
  protoToTypesInternalImpl(filepath)

macro protoToTypes*(filepath: static[string]): untyped =
  result = protoToTypesInternalImpl(filepath)

template import_proto3*(file: static[string]): untyped =
  const filepath = parentDir(instantiationInfo(-1, true).filename) / file
  protoToTypes(filepath)

when defined(ConformanceTest):
  macro protoToTypes2*(filepath: static[string]): untyped =
    result = protoToTypesInternalImpl(filepath, false)

  template import_proto2*(file: static[string]): untyped =
    const filepath = parentDir(instantiationInfo(-1, true).filename) / file
    protoToTypes2(filepath)
