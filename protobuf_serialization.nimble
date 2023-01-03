import os, strutils

mode = ScriptMode.Verbose

version       = "0.3.0"
author        = "Status"
description   = "Protobuf implementation compatible with the nim-serialization framework."
license       = "MIT"
skipDirs      = @["tests"]

requires "nim >= 1.2.0",
         "stew",
         "faststreams",
         "serialization",
         "combparser",
         "unittest2"

const styleCheckStyle =
  if (NimMajor, NimMinor) < (1, 6):
    "hint"
  else:
    "error"

proc test(args, path: string) =
  exec "nim " & getEnv("TEST_LANG", "c") & " " & getEnv("NIMFLAGS") & " " & args &
    " -r --hints:off --skipParentCfg --styleCheck:usages --styleCheck:" & styleCheckStyle & " " & path

task test, "Run all tests":
  #Explicitly specify the call depth limit in case the default changes in the future.
  test "--threads:off", "tests/test_all"
  test "--threads:on", "tests/test_all"

  #Also iterate over every test in tests/fail, and verify they fail to compile.
  echo "\r\n\x1B[0;94m[Suite]\x1B[0;37m Test Fail to Compile"
  var tests: seq[string] = @[]
  for path in listFiles(thisDir() / "tests" / "fail"):
    if path.split(".")[^1] != "nim":
      continue

    if gorgeEx("nim c " & path).exitCode != 0:
      echo "  \x1B[0;92m[OK]\x1B[0;37m ", path.split(DirSep)[^1]
    else:
      echo "  \x1B[0;31m[FAILED]\x1B[0;37m ", path.split(DirSep)[^1]
      exec "exit 1"
