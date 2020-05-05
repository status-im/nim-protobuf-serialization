mode = ScriptMode.Verbose

version       = "0.1.0"
author        = "Joey Yakimowich-Payne"
description   = "Protobuf implementation compatible with the nim-serialization framework."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests"]

requires "nim >= 1.2.0",
         "stew",
         "faststreams",
         "serialization"

task test, "Run all tests":
  exec "nim c -r --threads:off tests/test_all"
  exec "nim c -r --threads:on tests/test_all"
