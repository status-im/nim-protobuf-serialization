import os, strutils

mode = ScriptMode.Verbose

packageName   = "protobuf_serialization"
version       = "0.6.2"
author        = "Status"
description   = "Protobuf implementation compatible with the nim-serialization framework."
license       = "MIT"
skipDirs      = @["tests"]

requires "nim >= 2.2.4",
         "faststreams >= 0.6.0",
         "npeg >= 1.3.0",
         "serialization >= 0.5.4",
         "stew >= 0.6.0",
         "unittest2 >= 0.3.0"

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]
let platform = getEnv("PLATFORM", "")
let testArguments = [
  "-d:debug",
  "-d:release",
  "-d:danger",
]

let cfg =
  " --styleCheck:usages --styleCheck:error" &
  (if verbose: "" else: " --verbosity:0") &
  " --skipParentCfg --skipUserCfg --outdir:build -f " &
  quoteShell("--nimcache:build/nimcache/$projectName")

proc build(args, path: string) =
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & args & " " & path

proc run(args, path: string) =
  build args & " -r", path

task test, "Run all tests":
  for threads in ["--threads:off", "--threads:on"]:
    for args in testArguments:
      run threads & " " & args & " --mm:refc", "tests/test_all"
      run threads & " " & args & " --mm:orc", "tests/test_all"

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

task test_asan, "Run all tests with ASAN":
  if platform != "x86":
    # https://clang.llvm.org/docs/AddressSanitizer.html
    putEnv("ASAN_OPTIONS", "detect_leaks=0:detect_stack_use_after_return=1")
    # https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html
    putEnv("UBSAN_OPTIONS", "print_stacktrace=1")
    let asanArgs =
      " --mm:orc -d:useMalloc --cc:clang --debugger:native" &
      " --passC:-fsanitize=address,undefined" &
      " --passL:-fsanitize=address,undefined" &
      " --passC:-fno-sanitize-recover=undefined" &
      " --passC:-fno-sanitize-merge" &
      " --passC:-fno-omit-frame-pointer"
    for threads in ["--threads:off", "--threads:on"]:
      for args in testArguments:
        run threads & " " & args & asanArgs, "tests/test_all"

task conformance_test, "Run conformance tests":
  let
    pwd = thisDir()
    conformance = pwd / "conformance"
    test = pwd / "tests" / "conformance"

  if not system.dirExists(conformance):
    exec "git clone -b v30.0 --recurse-submodules https://github.com/protocolbuffers/protobuf/ " & conformance

  withDir conformance:
    exec "cmake . -Dprotobuf_BUILD_CONFORMANCE=ON"
    exec "make -j4 conformance_test_runner"

  exec "cp " & conformance / "conformance_test_runner" & " " & test
  withDir test:
    exec "nim c -d:ConformanceTest conformance_nim.nim"
    exec "./conformance_test_runner --enforce_recommended --failure_list failure_list.txt conformance_nim"

task examples, "Compile and run all examples":
  echo "\r\n\x1B[0;94m[Suite]\x1B[0;37m Examples"
  for path in listFiles(thisDir() / "examples"):
    if path.splitFile().ext != ".nim":
      continue
    let filename = path.splitFile().name
    echo "  Running: ", filename
    try:
      run("--mm:refc", path)
      run("--mm:orc", path)
      echo "  \x1B[0;92m[OK]\x1B[0;37m ", filename
    except:
      echo "  \x1B[0;31m[FAILED]\x1B[0;37m ", filename
      exec "exit 1"

task book, "Generate book":
  exec "mdbook build book -d ../docs"

task apidocs, "Generate API docs":
  exec "nim doc --project --outdir:docs/apidocs --index:on --git.url:https://github.com/status-im/nim-protobuf-serialization --git.commit:master protobuf_serialization.nim"
  exec "nim doc --project --outdir:docs/apidocs/protobuf_serialization --index:on --git.url:https://github.com/status-im/nim-protobuf-serialization --git.commit:master protobuf_serialization/proto_parser.nim"
  exec "nim buildIndex -o:docs/apidocs/protobuf_serialization/theindex.html docs/apidocs/protobuf_serialization"

task docs, "Generate docs":
  exec "nimble book"
  exec "nimble apidocs"
