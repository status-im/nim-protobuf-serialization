import os
import macros

import decldef
export decldef
import proto_parser

#Exported for the tests.
proc protoToTypesInternal*(proto: string): NimNode =
  var
    packages: seq[ProtoNode] = parseToDefinition(proto).packages
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
        name = next.enumName
        value = newNimNode(nnkEnumTy).add(newEmptyNode())
        for enumField in next.values:
          value.add(newNimNode(nnkEnumFieldDef).add(
            ident(enumField.fieldName),
            newIntLitNode(enumField.num)
          ))
      else:
        if (next.definedEnums.len != 0) or (next.nested.len != 0):
          queue.add(next)
          for nestee in (next.definedEnums & next.nested):
            queue.add(nestee)
          next.definedEnums = @[]
          next.nested = @[]
          continue

        name = next.messageName
        value = newNimNode(nnkObjectTy).add(
          newEmptyNode(),
          newEmptyNode(),
          newNimNode(nnkRecList)
        )

        for field in next.fields:
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

          var repeated: int = 0
          if field.repeated:
            repeated = 1

          case value[2][^1][1].strVal:
            of "double":
              value[2][^1][0][1].add(ident("pfloat64"))
              value[2][^1][1] = ident("float32")
            of "float32":
              value[2][^1][0][1].add(ident("pfloat32"))
            of "int32":
              value[2][^1][0][1].add(ident("pint"))
            of "int64":
              value[2][^1][0][1].add(ident("pint"))
            of "uint32":
              value[2][^1][0][1].add(ident("pint"))
            of "uint64":
              value[2][^1][0][1].add(ident("pint"))
            of "sint32":
              value[2][^1][0][1].add(ident("sint"))
              value[2][^1][1] = ident("int32")
            of "sint64":
              value[2][^1][0][1].add(ident("sint"))
              value[2][^1][1] = ident("int64")
            of "fixed32":
              value[2][^1][0][1].add(ident("fixed"))
              value[2][^1][1] = ident("uint32")
            of "fixed64":
              value[2][^1][0][1].add(ident("fixed"))
              value[2][^1][1] = ident("uint64")
            of "sfixed32":
              value[2][^1][0][1].add(ident("fixed"))
              value[2][^1][1] = ident("int32")
            of "sfixed64":
              value[2][^1][0][1].add(ident("fixed"))
              value[2][^1][1] = ident("int64")
            of "bool":
              discard
            of "string":
              discard
            of "bytes":
              repeated += 1
              value[2][^1][1] = ident("byte")

          for _ in 0 ..< repeated:
            value[2][^1][1] = newNimNode(nnkBracketExpr).add(
              ident("seq"),
              value[2][^1][1]
            )

        if value[2].len == 0:
          value[2] = newEmptyNode()

      result.add(
        newNimNode(nnkTypeDef).add(
          newNimNode(nnkPragmaExpr).add(
            newNimNode(nnkPostFix).add(ident("*"), ident(name)),
            newNimNode(nnkPragma).add(ident("protobuf3"))
          ),
          newEmptyNode(),
          value
        )
      )

macro protoToTypes*(proto: static[string]): untyped =
  result = protoToTypesInternal(proto)

template import_proto3*(file: static[string]): untyped =
  protoToTypes(staticRead(parentDir(instantiationInfo(-1, true).filename) / file))
