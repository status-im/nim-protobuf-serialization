import npeg, strutils, sequtils, macros, os, options, sets
import decldef

type
  TokenType = enum
    Ident, Integer, Float, String, Symbol, ToImport

  Token = ref object
    typ: TokenType
    text: string
    index: int

proc `$`(t: Token): string =
  $t.typ & ": " & t.text

proc `==`(t: Token, s: string): bool =
  result = t.typ == Ident and t.text == s

proc `==`(t: Token, tt: TokenType): bool =
  t.typ == tt

proc `==`(t: Token, c: char): bool =
  t.typ == Symbol and t.text[0] == c

proc tokenize(text: string): seq[Token] =
  let lexer = peg(tokens, res: seq[Token]):
    space     <- +Space
    comment   <- "//" * *(1 - '\n')
    comment2  <- "/*" * @"*/"

    octDigit  <- {'0'..'7'}
    hexDigit  <- {'0'..'9', 'a'..'f', 'A'..'F'}
    octEscape <- '\\' * octDigit[3]
    hexEscape <- '\\' * {'x', 'X'} * hexDigit[2]
    charEscape<- '\\' * {'a', 'b', 'f', 'n', 'r', 't', 'v', '\\', '\'', '"'}
    escapes   <- hexEscape | octEscape | charEscape
    dblstring <- '"' * *(escapes | 1 - '"') * '"':
      res.add Token(typ: String, text: ($0).unescape)
    regstring <- '\'' * *(escapes | 1 - '\'') * '\'':
      res.add Token(typ: String, text: ($0).unescape(prefix = "'", suffix = "'"))
    string    <- dblstring | regstring
    sym       <- {'=', ';', '{', '}', '[', ']', '<', '>', ','}:
      res.add Token(typ: Symbol, text: $0)
    # according to the official syntax, this is correct.
    # but in reality, leading underscores are accepted
    #ident    <- Alpha * *(Alpha | '_' | Digit)
    ident     <- (Alpha | '_') * *(Alpha | '_' | Digit)
    fullIdent <- ?'.' * ident * *('.' * ident):
      res.add Token(typ: Ident, text: $0)
    int       <- ?('-' | '+') * +(Digit):
      res.add Token(typ: Integer, text: $0)
    tokens    <- *(comment | comment2 | space | string | sym | int | fullIdent)

  let
    match = lexer.match(text, result)

  for index, tok in result:
    tok.index = index

  if match.matchLen != text.len:
    echo "Failed to lex around:"
    let
      minToShow = max(0, match.matchLen - 20)
      maxToShow = min(text.len, match.matchLen + 20)
    echo text[minToShow .. maxToShow]

type
  ParseState = ref object
    currentPackage: ProtoNode
    nodes: seq[ProtoNode]
    imports: seq[ProtoNode]
    idents: seq[Token]
    fields: seq[(Token, ProtoNode)]
    messages: seq[(Token, ProtoNode)]
    enums: seq[(Token, ProtoNode)]
    repeated, optional: bool
    reservedValues: seq[(Token, ProtoNode)]
    reservedBlocks: seq[(Token, ProtoNode)]
    rangeMax: Option[int]

proc extract(x: var seq[(Token, ProtoNode)], s: Token): seq[ProtoNode] =
  result = x.filterIt(it[0].index >= s.index).mapIt(it[1])
  x.keepItIf(it[0].index < s.index)

proc clearAfter(ps: ParseState, t: Token) =
  ps.idents.keepItIf(it.index < t.index)

proc parseProtoPackage(file: string, toImport: var HashSet[string]): ProtoNode =
  let tokens = file.readFile.tokenize

  let parser = peg(g, Token, ps: ParseState):
    ident      <- [Ident]:
      ps.idents.add $0
    string     <- [String]:
      ps.idents.add $0
    int        <- [Integer]:
      ps.idents.add $0
    pkg        <- ["package"] * ident * [';']:
      ps.currentPackage = ProtoNode(kind: Package, packageName: ps.idents[^1].text)
      ps.clearAfter($0)
    option     <- ["option"] * ident * ['='] * (ident | string) * [';']:
      ps.clearAfter($0)
    syntax     <- ["syntax"] * ['='] * string * [';']:
      ps.clearAfter($0)
    impor      <- ["import"] * string * [';']:
      ps.imports.add ProtoNode(kind: Imported, filename: ps.idents[^1].text)
      ps.clearAfter($0)
    fieldopt   <- ident * ['='] * ident:
      ps.clearAfter($0)
    fieldopts  <- ['['] * fieldopt * *([','] * fieldopt) * [']']

    oneoffield <- ident * ident * ['='] * int * ?fieldopts * [';']:
      let
        fieldType = ps.idents[^3].text
        fieldName = ps.idents[^2].text
        fieldValue = ps.idents[^1].text
      ps.fields.add (($0, ProtoNode(
          kind: Field,
          number: parseInt(fieldValue),
          protoType: fieldType,
          name: fieldName)))
      ps.clearAfter($0)
    oneof2     <- ["oneof"] * ident * ['{'] * *(option | oneoffield) * ['}']:
      let startIndex = ($0).index
      ps.fields.add(($0, ProtoNode(
        oneofName: tokens[startIndex + 1].text,
        kind: Oneof,
        oneof: ps.fields.extract($0)
      )))
      ps.clearAfter($0)

    rangeMax   <- int | ["max"]:
      if $0 == "max":
        ps.rangeMax = some(536870911)
      else:
        ps.rangeMax = some(parseInt(ps.idents[^1].text))
      ps.clearAfter($0)

    irange     <- int * ?(["to"] * rangeMax):
      if ps.rangeMax.isSome:
        ps.reservedValues.add(($0, ProtoNode(
          kind: Reserved,
          reservedKind: Range,
          startVal: parseInt(ps.idents[^1].text),
          endVal: ps.rangeMax.get())))
      else:
        ps.reservedValues.add(($0, ProtoNode(
          kind: Reserved,
          reservedKind: Number,
          intVal: parseInt(ps.idents[^1].text))))
      ps.rangeMax = none(int)
      ps.clearAfter($0)
    ranges     <- irange * *([','] * irange)

    identRange <- string:
      ps.reservedValues.add(($0, ProtoNode(
        kind: Reserved,
        reservedKind: ReservedType.String,
        strVal: ($0).text)))
      ps.clearAfter($0)

    idents     <- identRange * *([','] * identRange)
    reserved   <- ["reserved"] * (ranges | idents) * [';']:
      ps.reservedBlocks.add(($0, ProtoNode(
        kind: ReservedBlock,
        resValues: ps.reservedValues.extract($0))))

    multiple   <- (["singular"] | ["repeated"] | ["optional"]):
      if ($0).text == "repeated":
        ps.repeated = true
      elif ($0).text == "optional":
        ps.optional = true
    msgfield   <- ?multiple * ident * ident * ['='] * int * ?fieldopts * [';']:
      let
        fieldType = ps.idents[^3].text
        fieldName = ps.idents[^2].text
        fieldValue = ps.idents[^1].text
      ps.fields.add (($0, ProtoNode(
          kind: Field,
          number: parseInt(fieldValue),
          protoType: fieldType,
          name: fieldName,
          repeated: ps.repeated,
          optional: ps.optional)))
      ps.repeated = false
      ps.optional = false
      ps.clearAfter($0)
    mapfield   <- ["map"] * ['<'] * ident * [','] * ident * ['>'] * * ident * ['='] * int * ?fieldopts * [';']:
      let
        fieldType = "map<" & ps.idents[^4].text & ", " & ps.idents[^3].text & ">"
        fieldName = ps.idents[^2].text
        fieldValue = ps.idents[^1].text
      ps.fields.add (($0, ProtoNode(
          kind: Field,
          number: parseInt(fieldValue),
          protoType: fieldType,
          name: fieldName)))
      ps.clearAfter($0)
    message    <- ["message"] * ident * ['{'] * *(typedecl | mapfield | oneof2 | msgfield | reserved) * ['}']:
      let startIndex = ($0).index
      let fields = ps.fields.extract($0)
      ps.messages.add(($0, ProtoNode(
        messageName: tokens[startIndex + 1].text,
        kind: Message,
        nested: ps.messages.extract($0),
        definedEnums: ps.enums.extract($0),
        reserved: ps.reservedBlocks.extract($0),
        fields: fields
      )))
      ps.clearAfter($0)

    enumfield  <- ident * ['='] * int * [';']:
      let
        fieldName = ps.idents[^2].text
        fieldValue = ps.idents[^1].text
      ps.fields.add (($0, ProtoNode(
          kind: EnumVal,
          num: parseInt(fieldValue),
          fieldName: fieldName)))
      ps.clearAfter($0)
    enumdecl   <- ["enum"] * ident * ['{'] * *(option | enumfield) * ['}']:
      let startIndex = ($0).index
      let fields = ps.fields.extract($0)
      ps.enums.add(($0, ProtoNode(
        enumName: tokens[startIndex + 1].text,
        kind: Enum,
        values: fields
      )))
      ps.clearAfter($0)
    typedecl   <- (message | enumdecl)
    onething   <- (pkg | option | syntax | impor | typedecl)
    g          <- +onething

  var state = ParseState(currentPackage: ProtoNode(kind: Package))
  let match = parser.match(tokens, state)
  if match.matchLen != tokens.len:
    echo "Failed to parse around:"
    let
      minToShow = max(0, match.matchMax - 2)
      maxToShow = min(tokens.len, match.matchMax + 2)
    echo tokens[minToShow .. maxToShow]

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
