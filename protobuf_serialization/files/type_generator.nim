import os, algorithm, strutils, tables
import macros

import decldef
export decldef, tables
import proto_parser

proc getTypeAndPragma(strVal: string): (NimNode, NimNode) =
  result[0] = ident(strVal.split('.')[^1]) # TODO: Find a better way to handle namespaces
  case strVal:
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

proc isNested(base: string, currentName: string, messages: seq[ProtoNode]): bool =
  let msg = currentName.getMessage(messages)
  if msg.isNil():
    return false
  for field in msg.fields:
    if field.kind == ProtoType.Field:
      if field.presence == Repeated: continue
      if base == field.protoType or base.isNested(field.protoType, messages):
        return true
    elif field.kind == ProtoType.Oneof:
      for f in field.oneof:
        if f.presence == Repeated: continue
        if base == f.protoType or base.isNested(f.protoType, messages):
          return true

# Exported for the tests.
proc protoToTypesInternal*(filepath: string, logFile: string = ""): NimNode {.compileTime.} =
  var
    packages: seq[ProtoNode] = parseProtobuf(filepath).packages
    queue: seq[ProtoNode] = @[]
  result = newNimNode(nnkTypeSection)
  for parsed in packages:
    for msg in parsed.messages:
      queue.add(msg)
    for pbEnum in parsed.packageEnums:
      queue.add(pbEnum)

    while queue.len != 0:
      var
        next: ProtoNode = queue.pop()
        name: string
        value: NimNode
      if next.kind == ProtoType.Enum:
        # TODO: allow_alias
        var alreadySeen: seq[int] = @[]
        name = next.enumName
        value = newNimNode(nnkEnumTy).add(newEmptyNode())
        for enumField in next.values.sortedByIt(it.num):
          if enumField.num in alreadySeen:
            continue
          alreadySeen.add(enumField.num)
          value.add(newNimNode(nnkEnumFieldDef).add(
            ident(enumField.fieldName),
            newIntLitNode(enumField.num)
          ))
      else:
        if next.kind == ProtoType.Extend:
          continue
        if (next.definedEnums.len != 0) or (next.nested.len != 0):
          for nestee in (next.definedEnums & next.nested):
            queue.add(nestee)

        name = next.messageName
        value = newNimNode(nnkObjectTy).add(
          newEmptyNode(),
          newEmptyNode(),
          newNimNode(nnkRecList)
        )
        var fieldsQueue: seq[ProtoNode] = @[]
        for field in next.fields:
          fieldsQueue.add(field)
        while fieldsQueue.len != 0:
          let field = fieldsQueue.pop()
          if field.kind == Oneof:
            # TODO: ATM the oneof is ignore. Find a way to make it work
            for f in field.oneof:
              fieldsQueue.add(f)
            continue
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
            if next.messageName.isNested(field.protoType, parsed.messages):
              isReference = true
              break

          if value[2][^1][1].strVal.startsWith("map<"):
            var matches = value[2][^1][1].strVal.split({'<', '>', ','})
            let (typ1, _) = getTypeAndPragma(matches[1])
            let (typ2, _) = getTypeAndPragma(matches[2])
            value[2][^1][1] = nnkBracketExpr.newTree(newIdentNode("Table"), typ1, typ2)
          else:
            let (typ, pragma) = getTypeAndPragma(value[2][^1][1].strVal)
            value[2][^1][1] = typ
            if not pragma.isNil():
              value[2][^1][0][1].add(pragma)

          if field.presence == Repeated:
            value[2][^1][1] = newNimNode(nnkBracketExpr).add(
              ident("seq"),
              value[2][^1][1]
            )
          elif isReference:
            value[2][^1][1] = newNimNode(nnkRefTy).add(value[2][^1][1])
        if value[2].len == 0:
          value[2] = newEmptyNode()


      result.add(
        newNimNode(nnkTypeDef).add(
          newNimNode(nnkPragmaExpr).add(
            newNimNode(nnkPostfix).add(ident("*"), ident(name)),
            if next.kind == ProtoType.Enum:
              newNimNode(nnkPragma).add(ident("pure"))
            else:
              newNimNode(nnkPragma).add(ident("proto3"))
          ),
          newEmptyNode(),
          value
        )
      )
  if logFile != "":
    logFile.writeFile(repr(result))

macro protoToTypes*(filepath: static[string], logFile: static[string] = ""): untyped =
  result = protoToTypesInternal(filepath, logFile)

template import_proto3*(file: static[string], logFile: static[string] = ""): untyped =
  const filepath = parentDir(instantiationInfo(-1, true).filename) / file
  protoToTypes(filepath, logFile)
