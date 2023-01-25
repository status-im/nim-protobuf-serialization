import unittest2

import
  ../protobuf_serialization,
  ../protobuf_serialization/codec

type
  Classic = enum
    A1
    B1
    C1

  WithHoles = enum
    A2 = -10
    B2 = 0
    C2 = 10
    D2

  Limits = enum
    A3 = int32.low()
    B3 = 0
    C3 = int32.high()

  ObjClassicP2 {.proto2.} = object
    x {.fieldNumber: 1, required.}: Classic

  ObjWithHolesP2 {.proto2.} = object
    x {.fieldNumber: 1, required.}: WithHoles

  ObjLimitsP2 {.proto2.} = object
    x {.fieldNumber: 1, required.}: Limits

  ObjClassicP3 {.proto3.} = object
    x {.fieldNumber: 1.}: Classic

  ObjWithHolesP3 {.proto3.} = object
    x {.fieldNumber: 1.}: WithHoles

  ObjLimitsP3 {.proto3.} = object
    x {.fieldNumber: 1.}: Limits

suite "Test Enum Encoding/Decoding":
  test "Can encode/decode enum":
    for x in @[A1, B1, C1]:
      let
        objp2 = ObjClassicP2(x: x)
        objp3 = ObjClassicP3(x: x)
        encodedp2 = Protobuf.encode(objp2)
        encodedp3 = Protobuf.encode(objp3)
      check Protobuf.decode(encodedp2, ObjClassicP2) == objp2
      check Protobuf.decode(encodedp3, ObjClassicP3) == objp3

  test "Can encode/decode enum with holes":
    for x in @[A2, B2, C2, D2]:
      let
        objp2 = ObjWithHolesP2(x: x)
        objp3 = ObjWithHolesP3(x: x)
        encodedp2 = Protobuf.encode(objp2)
        encodedp3 = Protobuf.encode(objp3)
      check Protobuf.decode(encodedp2, ObjWithHolesP2) == objp2
      check Protobuf.decode(encodedp3, ObjWithHolesP3) == objp3

  test "Can encode/decode enum limits":
    for x in @[A3, B3, C3]:
      let
        objp2 = ObjLimitsP2(x: x)
        objp3 = ObjLimitsP3(x: x)
        encodedp2 = Protobuf.encode(objp2)
        encodedp3 = Protobuf.encode(objp3)
      check Protobuf.decode(encodedp2, ObjLimitsP2) == objp2
      check Protobuf.decode(encodedp3, ObjLimitsP3) == objp3

  test "Decode out of range enum":
    # TODO: Find a way to save the unrecognized value
    check:
      Protobuf.decode(@[8'u8, 4], ObjWithHolesP2) == ObjWithHolesP2() # Inside the hole
      Protobuf.decode(@[8'u8, 4], ObjWithHolesP3) == ObjWithHolesP3() # Inside the hole
      Protobuf.decode(@[8'u8, 24], ObjWithHolesP2) == ObjWithHolesP2() # Outside the hole
      Protobuf.decode(@[8'u8, 24], ObjWithHolesP3) == ObjWithHolesP3() # Outside the hole
