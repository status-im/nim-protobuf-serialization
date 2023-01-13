import npeg, strutils, sequtils, macros, os, options
import decldef

type
  TokenType = enum
    Ident, Integer, Float, String, Symbol, ToImport

  Token = ref object
    typ: TokenType
    text: string
    index: int
    line: int

proc `$`(t: Token): string =
  $t.typ & ": " & t.text

proc `==`(t: Token, s: string): bool =
  result = t.typ == Ident and t.text == s

proc `==`(t: Token, tt: TokenType): bool =
  t.typ == tt

proc `==`(t: Token, c: char): bool =
  t.typ == Symbol and t.text[0] == c

proc tokenize(f: string): seq[Token] =
  let lexer = peg(tokens, res: seq[Token]):
    space    <- +Space
    comment  <- "//" * *(1 - '\n')
    comment2 <- "/*" * @"*/"
    dblstring<- '"' * *(1 - '"') * '"'
    regstring<- '\'' * *(1 - '\'') * '\''
    string   <- dblstring | regstring:
      res.add Token(typ: String, text: $0)
    symbol   <- {'=', ';', '{', '}', '[', ']', '<', '>', ','}:
      res.add Token(typ: Symbol, text: $0)
    # according to the official syntax, this is correct.
    # but in reality, leading underscores are accepted
    #ident    <- Alpha * *(Alpha | '_' | Digit)
    ident    <- (Alpha | '_') * *(Alpha | '_' | Digit)
    fullIdent<- ?'.' * ident * *('.' * ident):
      res.add Token(typ: Ident, text: $0)
    integer  <- ?('-' | '+') * +(Digit):
      res.add Token(typ: Integer, text: $0)
    tokens   <- *(comment | comment2 | space | string | symbol | integer | fullIdent)

  let
    text = f.readFile()
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

proc parseProtobuf(f: string): seq[ProtoNode] =
  let tokens = f.tokenize

  let parser = peg(g, Token, ps: ParseState):
    ident      <- [Ident]:
      ps.idents.add $0
    string     <- [String]:
      ps.idents.add $0
    int        <- [Integer]:
      ps.idents.add $0
    package    <- ["package"] * ident * [';']:
      ps.currentPackage = ProtoNode(kind: Package, packageName: ps.idents[^1].text)
      ps.clearAfter($0)
    option     <- ["option"] * ident * ['='] * (ident | string) * [';']:
      ps.clearAfter($0)
    syntax     <- ["syntax"] * ['='] * string * [';']:
      ps.clearAfter($0)
    impor      <- ["import"] * string * [';']:
      ps.nodes.add ProtoNode(kind: Imported, filename: ps.idents[^1].text)
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
    oneof      <- ["oneof"] * ident * ['{'] * *(option | oneoffield) * ['}']:
      let startIndex = ($0).index
      ps.fields.add(($0, ProtoNode(
        oneofName: tokens[startIndex + 1].text,
        kind: Oneof,
        oneof: ps.fields.extract($0)
      )))
      ps.clearAfter($0)

    rangemax   <- int | ["max"]:
      if $0 == "max":
        ps.rangeMax = some(536870911)
      else:
        ps.rangeMax = some(parseInt(ps.idents[^1].text))
      ps.clearAfter($0)

    range      <- int * ?(["to"] * rangemax):
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
    ranges     <- range * *([','] * range)
    identRange <- ident:
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

    multiple   <- (["repeated"] | ["optional"]):
      if ($0).text == "repeated":
        ps.repeated = true
      else:
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
    message    <- ["message"] * ident * ['{'] * *(typedecl | mapfield | oneof | msgfield | reserved) * ['}']:
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
    onething   <- (package | option | syntax | impor | typedecl)
    g          <- +onething

  var state = ParseState()
  let match = parser.match(tokens, state)
  state.nodes &= state.messages.mapIt(it[1])
  state.nodes &= state.enums.mapIt(it[1])
  if match.matchLen != tokens.len:
    echo "Failed to parse around:"
    let
      minToShow = max(0, match.matchMax - 2)
      maxToShow = min(tokens.len, match.matchMax + 2)
    echo tokens[minToShow .. maxToShow]
  result = state.nodes

let res = parseProtobuf("tests/files/test_messages_proto3.proto")
echo "----"
for x in res:
  echo x
