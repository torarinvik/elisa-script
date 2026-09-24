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
the same exit status and captured stdout. The parity harness additionally
compares both executable process results (status, stdout, stderr) and verifies
that both declared executable files exist and can be run.

`test/script_parity/minimal_native_build_launcher_test.elisascript` is the
end-to-end process parity harness. It accepts `ELISASCRIPT_MINIMAL_NATIVE_CMAKE`
for the CMake executable, requires `ELISASCRIPT_PUBLIC_LAUNCHER` to resolve to
the pinned local Elisa compiler, and creates distinct fresh CMake and
ElisaScript build directories under a private `temp_directory`. It configures
the reference with Unix Makefiles, builds serially, runs CTest, builds the
ElisaScript target through the pinned public launcher, and compares the two
executables. All commands use argv vectors, a controlled environment, empty
stdin, per-process timeouts, and bounded output capture. The test removes only
its generated temporary workspace. It is gated on explicit reauthorization and
the RSS-supervised wrapper marker. The wrapper samples the compiler process
group and descendant tree, including build-tool children, but this sampled RSS
guard is not an OS-enforced memory cap.

## Evidence status

The fixture source encodes both expected outcomes, but no CMake configure/build,
CTest, ElisaScript compile/run, or cross-route process comparison has been
executed. This contract and the unexecuted comparison test are not yet parity
evidence or an E01 acceptance result.
