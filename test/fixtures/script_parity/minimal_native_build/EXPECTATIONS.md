# Minimal native build parity contract

This fixture is the E01 starting point in `SCRIPT_TASKS.md`. It compares the
behavior of a small native executable produced by the CMake reference with the
same program produced by `build.elisascript`. Build-tool diagnostics are not
compared: CMake and ElisaScript are different build frontends. The executable's
observable process result is the parity surface.

## Inputs and build contract

- Sources: `src/main.c` and `src/answer.c`; include root: `include/`.
- Language mode: required ISO C11 with compiler extensions disabled.
- GNU and Clang-family builds enable `-pedantic -Wall -Wextra -Werror`.
- Target name: `minimal-native`.
- Build outputs must be placed in separate caller-provided directories outside
  the source repository. The fixture must not remove caller-owned paths.
- The ElisaScript recipe submits compiler arguments as an argument vector and
  declares the executable output; it must not invoke a shell to parse a command
  string.

## Program observation

Run each produced executable independently with no arguments and an empty
stdin. Both runs must complete within 10 seconds and produce exactly:

```text
exit status: 0
stdout:      answer=42\n
stderr:      empty
```

The CMake route registers `minimal-native-output` with CTest and checks the
`answer=42` output. The ElisaScript route has a dependent run node that checks
the same exit status and captured stdout. A parity harness should compare the
two process results (status, stdout, stderr) and separately verify that both
declared executable files exist and can be run.

`test/script_parity/minimal_native_build_launcher_test.elisascript` implements
the process-result comparison for prebuilt artifacts. Supply the absolute paths
through `ELISASCRIPT_MINIMAL_NATIVE_CMAKE_BINARY` and
`ELISASCRIPT_MINIMAL_NATIVE_ELISA_BINARY`; it rejects symlink paths, oversized
files, paths inside the repository, and outputs sharing one directory. The
fixture runs only those two executables, with an empty environment except for
controlled locale and `PATH`, empty stdin, a fixed timeout, and a bounded
combined output budget. The test is gated on explicit reauthorization and the
RSS-supervised wrapper marker. It does not build either artifact and therefore
does not attest build provenance; the caller must build them with the two
recipes above before comparing their behavior.

## Evidence status

The fixture source encodes both expected outcomes, but no CMake configure/build,
CTest, ElisaScript compile/run, or cross-route process comparison has been
executed. This contract and the unexecuted comparison test are not yet parity
evidence or an E01 acceptance result.
