import npeg, strutils, sequtils, macros, os, options, sets
import decldef

type
  TokenType = enum
    Ident, Integer, Float, String, Symbol, ToImport

  Token = ref object
    typ: TokenType
    text: string
    index: int
    filePos: int

proc `$`(t: Token): string =
  $t.typ & ": " & t.text

proc `==`(t: Token, s: string): bool =
  result = t.typ == Ident and t.text == s

proc `==`(t: Token, tt: TokenType): bool =
  t.typ == tt

proc `==`(t: Token, c: char): bool =
  t.typ == Symbol and t.text[0] == c

proc tokenize(filename, text: string): seq[Token] =
  let lexer = peg(tokens, res: seq[Token]):
    space      <- +Space
    comment    <- "//" * *(1 - '\n')
    comment2   <- "/*" * @"*/"

    decDigit   <- {'0'..'9'}
    octDigit   <- {'0'..'7'}
    hexDigit   <- {'0'..'9', 'a'..'f', 'A'..'F'}
    octEscape  <- '\\' * octDigit[3]
    hexEscape  <- '\\' * {'x', 'X'} * hexDigit[2]
    charEscape <- '\\' * {'a', 'b', 'f', 'n', 'r', 't', 'v', '\\', '\'', '"'}
    escapes    <- hexEscape | octEscape | charEscape
    dblstring  <- '"' * *(escapes | 1 - '"') * '"':
      res.add Token(typ: String, text: ($0).unescape, filePos: @0)
    regstring  <- '\'' * *(escapes | 1 - '\'') * '\'':
      res.add Token(typ: String, text: ($0).unescape(prefix = "'", suffix = "'"), filePos: @0)
    string     <- dblstring | regstring
    sym        <- {'=', ';', '{', '}', '[', ']', '<', '>', ','}:
      res.add Token(typ: Symbol, text: $0, filePos: @0)
    # according to the official syntax, this is correct.
    # but in reality, leading underscores are accepted
    #ident     <- Alpha * *(Alpha | '_' | Digit)
    ident      <- (Alpha | '_') * *(Alpha | '_' | Digit)
    fullIdent  <- ?'.' * ident * *('.' * ident):
      res.add Token(typ: Ident, text: $0, filePos: @0)

    decimals   <- +decDigit
    exponent   <- {'e', 'E'} * ?('+' | '-') * decimals
    floatLit   <- "inf" | "nan" | ((decimals * '.' * ?decimals * ?exponent) | (decimals * exponent) | ('.' * decimals * ?exponent)):
      res.add Token(typ: Float, text: $0, filePos: @0)
    int        <- ?('-' | '+') * +(Digit):
      res.add Token(typ: Integer, text: $0, filePos: @0)
    tokens     <- *(comment | comment2 | space | string | sym | floatLit | int | fullIdent)

  let
    match = lexer.match(text, result)

  for index, tok in result:
    tok.index = index

  if match.matchLen != text.len:
    let line = text[0..<match.matchMax].count('\n') + 1
    var msg = filename & ":" & $line & " Failed to lex '" & text[match.matchMax] & "'\n"
    var
      minToShow = text.rfind('\n', 0, match.matchMax) + 1
      maxToShow = text.find('\n', match.matchMax)
    if maxToShow == -1: maxToShow = text.len
    msg &= text[minToShow ..< maxToShow]
    raise newException(CatchableError, msg)

type
  ParseState = ref object
    currentPackage: ProtoNode
    imports: seq[ProtoNode]
    fields: seq[(Token, ProtoNode)]
    messages: seq[(Token, ProtoNode)]
    enums: seq[(Token, ProtoNode)]
    reservedValues: seq[ProtoNode]
    reservedBlocks: seq[(Token, ProtoNode)]

proc extract(x: var seq[(Token, ProtoNode)], s: Token): seq[ProtoNode] =
  # The "extract mechanism" is used to handle this case:
  # message xx {
  #   int a = 1;
  #   message yy {}
  #   int b = 2;
  # }
  #
  # When matching "yy", we want to leave `a` in the list for when `xx` will be finished.
  # To do so, we will get every `field` with index >= to the first match of `yy`,
  # and leave the rest to be matched later.
  #
  # This is a bit ugly, but I'm not aware of a better solution with npeg.
  result = x.filterIt(it[0].index >= s.index).mapIt(it[1])
  x.keepItIf(it[0].index < s.index)

proc parseProtoPackage(file: string, toImport: var HashSet[string]): ProtoNode =
  let
    fileContent = file.readFile
    fileName = file.extractFilename
    tokens = tokenize(fileName, fileContent)

  let parser = peg(g, Token, ps: ParseState):
    ident      <- [Ident]
    string     <- [String]
    int        <- [Integer]
    float      <- [Float]

    pkg        <- ["package"] * >ident * [';']:
      ps.currentPackage = ProtoNode(kind: Package, packageName: ($1).text)
    option     <- ["option"] * ident * ['='] * (ident | string | int | float) * [';']
    syntax     <- ["syntax"] * ['='] * string * [';']
    impor      <- ["import"] * >string * [';']:
      ps.imports.add ProtoNode(kind: Imported, filename: ($1).text)

    fieldopt   <- ident * ['='] * (ident | int | string | float)
    fieldopts  <- ['['] * fieldopt * *([','] * fieldopt) * [']']

    oneoffield <- >ident * >ident * ['='] * >int * ?fieldopts * [';']:
      let
        fieldType = ($1).text
        fieldName = ($2).text
        fieldValue = ($3).text
      ps.fields.add (($0, ProtoNode(
          kind: Field,
          number: parseInt(fieldValue),
          protoType: fieldType,
          name: fieldName)))
    oneof2     <- ["oneof"] * >ident * ['{'] * *(option | oneoffield) * ['}']:
      ps.fields.add(($0, ProtoNode(
        oneofName: ($1).text,
        kind: Oneof,
        oneof: ps.fields.extract($0)
      )))

    rangeMax   <- int | ["max"]
    irange     <- int * ?(["to"] * >rangeMax):
      if capture.len > 1:
        ps.reservedValues.add(ProtoNode(
          kind: Reserved,
          reservedKind: Range,
          startVal: parseInt(($0).text),
          endVal:
            if $1 == "max":
              536870911
            else:
              parseInt(($1).text)
          ))
      else:
        ps.reservedValues.add(ProtoNode(
          kind: Reserved,
          reservedKind: Number,
          intVal: parseInt(($0).text)))
    ranges     <- irange * *([','] * irange)

    identRange <- string:
      ps.reservedValues.add(ProtoNode(
        kind: Reserved,
        reservedKind: ReservedType.String,
        strVal: ($0).text))

    idents     <- identRange * *([','] * identRange)
    reserved   <- ["reserved"] * (ranges | idents) * [';']:
      ps.reservedBlocks.add(($0, ProtoNode(
        kind: ReservedBlock,
        resValues: ps.reservedValues)))
      ps.reservedValues = newSeq[ProtoNode]()

    extensions <- ["extensions"] * (ranges | idents) * [';']:
      ps.reservedValues = newSeq[ProtoNode]()

    multiple   <- (["singular"] | ["repeated"] | ["optional"] | ["required"])
    msgfield   <- >?multiple * >ident * >ident * ['='] * >int * ?fieldopts * [';']:
      let
        fieldType = ($2).text
        fieldName = ($3).text
        fieldValue = ($4).text
      let node = ProtoNode(
          kind: Field,
          number: parseInt(fieldValue),
          protoType: fieldType,
          name: fieldName)
      if @1 != @2:
        node.presence = parseEnum[Presence](($1).text.toUpper)
      ps.fields.add (($0, node))
    mapfield   <- ["map"] * ['<'] * >ident * [','] * >ident * ['>'] * * >ident * ['='] * >int * ?fieldopts * [';']:
      let
        fieldType = "map<" & ($1).text & ", " & ($2).text & ">"
        fieldName = ($3).text
        fieldValue = ($4).text
      ps.fields.add (($0, ProtoNode(
          kind: Field,
          number: parseInt(fieldValue),
          protoType: fieldType,
          name: fieldName)))

    # protobuf2
    groupfield <- ?multiple * >["group"] * >ident * ['='] * >int * msgbody:
      let fields = ps.fields.extract($0)
      ps.messages.add(($0, ProtoNode(
        messageName: ($2).text,
        kind: Message,
        nested: ps.messages.extract($0),
        definedEnums: ps.enums.extract($0),
        reserved: ps.reservedBlocks.extract($0),
        fields: fields
      )))

      let
        fieldType = ($2).text
        fieldName = ($2).text
        fieldValue = ($3).text
      let node = ProtoNode(
          kind: Field,
          number: parseInt(fieldValue),
          protoType: fieldType,
          name: fieldName)
      if @1 != @2:
        node.presence = parseEnum[Presence](($0).text.toUpper)
      ps.fields.add (($0, node))

    extend     <- ["extend"] * >ident * msgbody:
      let fields = ps.fields.extract($0)
      ps.messages.add(($0, ProtoNode(
        extending: ($1).text,
        kind: Extend,
        extendedFields: fields
      )))

    msgbody    <- ['{'] * *(typedecl | mapfield | oneof2 | msgfield | reserved | extensions | groupfield | option | extend) * ['}']
    msg        <- ["message"] * >ident * msgbody:
      let fields = ps.fields.extract($0)
      ps.messages.add(($0, ProtoNode(
        messageName: ($1).text,
        kind: Message,
        nested: ps.messages.extract($0),
        definedEnums: ps.enums.extract($0),
        reserved: ps.reservedBlocks.extract($0),
        fields: fields
      )))


    enumfield  <- >ident * ['='] * >int * [';']:
      let
        fieldName = ($1).text
        fieldValue = ($2).text
      ps.fields.add (($0, ProtoNode(
          kind: EnumVal,
          num: parseInt(fieldValue),
          fieldName: fieldName)))
    enumdecl   <- ["enum"] * >ident * ['{'] * *(option | enumfield) * ['}']:
      ps.enums.add(($0, ProtoNode(
        enumName: ($1).text,
        kind: Enum,
        values: ps.fields.extract($0)
      )))
    typedecl   <- (msg | enumdecl)
    onething   <- (pkg | option | syntax | impor | typedecl | extend)
    g          <- +onething

  var state = ParseState(currentPackage: ProtoNode(kind: Package))
  let match = parser.match(tokens, state)
  if match.matchLen != tokens.len:
    let
      tokenPos = tokens[match.matchMax].filePos
      line = fileContent[0..<tokenPos].count('\n') + 1
    var msg = filename & ":" & $line & " Failed to parse: '" & tokens[match.matchMax].text & "'\n"
    var
      minToShow = fileContent.rfind('\n', 0, tokenPos) + 1
      maxToShow = fileContent.find('\n', tokenPos)
    if maxToShow == -1: maxToShow = msg.len
    msg &= fileContent[minToShow ..< maxToShow]
    raise newException(CatchableError, msg)

  result = state.currentPackage
  result.messages &= state.messages.mapIt(it[1])
  result.packageEnums &= state.enums.mapIt(it[1])

  for impors in state.imports:
    const googlePrefix = "google/protobuf/"
    if impors.filename.startsWith(googlePrefix):
      # When used at runtime, this won't be portable!
      let
        googleFolder = currentSourcePath.parentDir / "google"
        fixedPath = impors.filename[googlePrefix.len..^1].absolutePath(googleFolder)
      toImport.incl(fixedPath)
    else:
      toImport.incl(impors.filename.absolutePath(file.parentDir))

proc parseProtobuf*(file: string): ProtoNode =
  doAssert file.isAbsolute
  var
    toImport = toHashSet([file])
    imported: HashSet[string]
  result = ProtoNode(kind: ProtoDef, packages: @[])
  while imported.len != toImport.len:
    for toImp in toImport:
      if toImp notin imported:
        result.packages.add(parseProtoPackage(toImp, toImport))
        imported.incl(toImp)
        break
