#[
Copyright (c) 2018-2020 Peter Munch-Ellingsen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]#

import strutils

type
  ReservedType* = enum
    String, Number, Range
  ProtoType* = enum
    Field, Enum, EnumVal, ReservedBlock, Reserved, Message, File, Imported, Oneof, Package, ProtoDef, Extend
  Presence* = enum
    Singular, Repeated, Optional, Required
  ProtoNode* = ref object
    case kind*: ProtoType
    of Field:
      number*: int
      protoType*: string
      name*: string
      presence*: Presence
    of Oneof:
      oneofName*: string
      oneof*: seq[ProtoNode]
    of Enum:
      enumName*: string
      values*: seq[ProtoNode]
    of EnumVal:
      fieldName*: string
      num*: int
    of ReservedBlock:
      resValues*: seq[ProtoNode]
    of Reserved:
      case reservedKind*: ReservedType
      of ReservedType.String:
        strVal*: string
      of ReservedType.Number:
        intVal*: int
      of ReservedType.Range:
        startVal*: int
        endVal*: int
    of Message:
      messageName*: string
      reserved*: seq[ProtoNode]
      definedEnums*: seq[ProtoNode]
      fields*: seq[ProtoNode]
      nested*: seq[ProtoNode]
    of Extend:
      extending*: string
      extendedFields*: seq[ProtoNode]
    of Package:
      packageName*: string
      messages*: seq[ProtoNode]
      packageEnums*: seq[ProtoNode]
    of File:
      syntax*: string
      imported*: seq[ProtoNode]
      package*: ProtoNode
    of ProtoDef:
      packages*: seq[ProtoNode]
    of Imported:
      filename*: string


proc `$`*(node: ProtoNode): string =
  case node.kind:
    of Field:
      result = "$1 field $2 of type $3 with index $4".format(
        $node.presence,
        node.name,
        node.protoType,
        node.number)
    of Oneof:
      result = "One-of named $1, with one of these fields:\n".format(
        node.oneofName)
      var fields = ""
      for field in node.oneof:
        fields &= $field & "\n"
      result &= fields[0..^2].indent(1, "  ")
    of Enum:
      result = "Enum $1 has values:\n".format(
        node.enumName)
      var fields = ""
      for field in node.values:
        fields &= $field & "\n"
      result &= fields[0..^2].indent(1, "  ")
    of EnumVal:
      result = "Enum field $1 with index $2".format(
        node.fieldName,
        node.num)
    of ReservedBlock:
      result = "Reserved values:\n"
      var reserved = ""
      for value in node.resValues:
        reserved &= $value & "\n"
      result &= reserved.indent(1, "  ")
    of Reserved:
      result = case node.reservedKind:
        of ReservedType.String:
          "Reserved field name $1".format(
            node.strVal)
        of ReservedType.Number:
          "Reserved field index $1".format(
            node.intVal)
        of ReservedType.Range:
          "Reserved field index from $1 to $2".format(
            node.startVal, node.endVal)
    of Message:
      result = "Message $1 with data:".format(
        node.messageName)
      var data = ""
      if node.reserved.len != 0:
        data &= "\nReserved fields:"
        var reserved = "\n"
        for res in node.reserved:
          reserved &= $res & "\n"
        data &= reserved[0..^2].indent(1, "  ")
      if node.definedEnums.len != 0:
        data &= "\nEnumerable definitions:"
        var enums = "\n"
        for definedEnum in node.definedEnums:
          enums &= $definedEnum & "\n"
        data &= enums[0..^2].indent(1, "  ")
      if node.fields.len != 0:
        data &= "\nDefined fields:"
        var fields = "\n"
        for field in node.fields:
          fields &= $field & "\n"
        data &= fields[0..^2].indent(1, "  ")
      if node.nested.len != 0:
        data &= "\nAnd nested messages:"
        var messages = "\n"
        for message in node.nested:
          messages &= $message & "\n"
        data &= messages[0..^2].indent(1, "  ")
      result &= data.indent(1, "  ")
    of Extend:
      result = "Extension of $1 with fields:".format(node.extending)
      var data = ""
      var fields = "\n"
      for field in node.extendedFields:
        fields &= $field & "\n"
      data &= fields[0..^2].indent(1, "  ")
      result &= data.indent(1, "  ")
    of File:
      result = "Protobuf file with syntax $1\n".format(
        node.syntax)
      if node.imported.len != 0:
        var body = "Imported:\n"
        for imp in node.imported:
          body &= ($imp).indent(1, "  ")
          result &= body.indent(1, "  ") & "\n"
          body = "\n"
      if node.package != nil:
        result &= $node.package
      else:
        result &= "Without own package"
    of Package:
      result = "Package$1:\n".format(if node.packageName.len != 0: " with name " & node.packageName else: "")
      for message in node.messages:
        result &= ($message).indent(1, "  ") & "\n"
      for enumeration in node.packageEnums:
        result &= ($enumeration).indent(1, "  ")
    of ProtoDef:
      result = ""
      for package in node.packages:
        result &= $package
    of Imported:
      result = "Imported file " & node.filename
