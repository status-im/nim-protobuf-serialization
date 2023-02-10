import os, strutils

mode = ScriptMode.Verbose

packageName   = "protobuf_serialization"
version       = "0.3.0"
author        = "Status"
description   = "Protobuf implementation compatible with the nim-serialization framework."
license       = "MIT"
skipDirs      = @["tests"]

requires "nim >= 1.2.0",
         "stew",
         "faststreams",
         "serialization",
         "npeg#22449099", # waiting for this to be in a release
         "unittest2"

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]

let styleCheckStyle = if (NimMajor, NimMinor) < (1, 6): "hint" else: "error"
let cfg =
  " --styleCheck:usages --styleCheck:" & styleCheckStyle &
  (if verbose: "" else: " --verbosity:0 --hints:off") &
  " --skipParentCfg --skipUserCfg --outdir:build --nimcache:build/nimcache -f"

proc build(args, path: string) =
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & args & " " & path

proc run(args, path: string) =
  build args & " -r", path

task test, "Run all tests":
  for threads in ["--threads:off", "--threads:on"]:
    run threads, "tests/test_all"

  #Also iterate over every test in tests/fail, and verify they fail to compile.
  echo "\r\n\x1B[0;94m[Suite]\x1B[0;37m Test Fail to Compile"
  var tests: seq[string] = @[]
  for path in listFiles(thisDir() / "tests" / "fail"):
    if path.split(".")[^1] != "nim":
      continue

    if gorgeEx(nimc & " c " & path).exitCode != 0:
      echo "  \x1B[0;92m[OK]\x1B[0;37m ", path.split(DirSep)[^1]
    else:
      echo "  \x1B[0;31m[FAILED]\x1B[0;37m ", path.split(DirSep)[^1]
      exec "exit 1"

task conformance_test, "Run conformance tests":
  let
    pwd = thisDir()
    conformance = pwd / "conformance"
    test = pwd / "tests" / "conformance"
  if not dirExists(conformance):
    exec "git clone --recurse-submodules https://github.com/protocolbuffers/protobuf/ " & conformance
    # exec "git clone --recursive https://github.com/protocolbuffers/protobuf/ " & conformance
  # exec "bash -c 'cd " & conformance & " && cmake . -Dprotobuf_BUILD_CONFORMANCE=ON && cmake --build .'"
  withDir conformance:
    exec "cmake . -Dprotobuf_BUILD_CONFORMANCE=ON"
    exec "make conformance_test_runner"
  exec "cp " & conformance / "conformance_test_runner" & " " & test
  exec "nim c " & test /  "conformance_nim.nim"
  exec test / "conformance_test_runner --verbose " & test / "conformance_nim"
