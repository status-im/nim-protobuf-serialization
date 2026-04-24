import
  std/[os, algorithm, strutils, tables, sets, macros],
  stew/shims/macros as stewmacros,
  ./[decldef, proto_parser]

export decldef, tables

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

# Exported for the tests.
proc protoToTypesInternal*(filepath: string, isProto3 = true): NimNode {.compileTime.} =
  var
    packages: seq[ProtoNode] = parseProtobuf(filepath).packages
    queue: seq[ProtoNode] = @[]
    enumNames = initHashSet[string]()
  result = newNimNode(nnkTypeSection)
  for parsed in packages:
    for msg in parsed.messages:
      if msg.kind != ProtoType.Extend:
        for pbEnum in msg.definedEnums:
          enumNames.incl pbEnum.enumName
    for pbEnum in parsed.packageEnums:
      enumNames.incl pbEnum.enumName
  for parsed in packages:
    for msg in parsed.messages:
      queue.add(msg)
      if msg.kind != ProtoType.Extend:
        for field in msg.fields:
          if field.kind == ProtoType.Oneof:
            # XXX this should be supported
            continue
          if field.protoType.startsWith("map<"):
            let matches = field.protoType.split({'<', '>', ','})
            let entryFields = @[
              ProtoNode(kind: Field, number: 1, protoType: matches[1], name: "key"),
              ProtoNode(kind: Field, number: 2, protoType: matches[2], name: "value")
            ]
            queue.add ProtoNode(
              kind: Message,
              messageName: field.name & "Entry",
              fields: entryFields)
      # TODO: define Enums first to workaround https://github.com/nim-lang/Nim/issues/25651
      if msg.kind != ProtoType.Extend:
        if (msg.definedEnums.len != 0) or (msg.nested.len != 0):
          for nestee in (msg.definedEnums & msg.nested):
            queue.add(nestee)
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
        #if (next.definedEnums.len != 0) or (next.nested.len != 0):
        #  for nestee in (next.definedEnums & next.nested):
        #    queue.add(nestee)

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
            # TODO: ATM the oneof is ignored. Find a way to make it work
            for f in field.oneof:
              f.presence = Optional
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
            value[2][^1][1] = newNimNode(nnkBracketExpr).add(
              ident("seq"), ident(field.name & "Entry")
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
        if value[2].len == 0:
          value[2] = newEmptyNode()

      let protoVer = if isProto3:
        "proto3"
      else:
        "proto2"

      result.add(
        newNimNode(nnkTypeDef).add(
          newNimNode(nnkPragmaExpr).add(
            newNimNode(nnkPostfix).add(ident("*"), ident(name)),
            if next.kind == ProtoType.Enum:
              newNimNode(nnkPragma).add(ident("pure"), ident(protoVer))
            else:
              newNimNode(nnkPragma).add(ident(protoVer))
          ),
          newEmptyNode(),
          value
        )
      )
  when defined(LogGeneratedTypes):
    result.storeMacroResult(true)

macro protoToTypes*(filepath: static[string]): untyped =
  result = protoToTypesInternal(filepath)

template import_proto3*(file: static[string]): untyped =
  const filepath = parentDir(instantiationInfo(-1, true).filename) / file
  protoToTypes(filepath)

when defined(ConformanceTest):
  macro protoToTypes2*(filepath: static[string]): untyped =
    result = protoToTypesInternal(filepath, false)

  template import_proto2*(file: static[string]): untyped =
    const filepath = parentDir(instantiationInfo(-1, true).filename) / file
    protoToTypes2(filepath)
