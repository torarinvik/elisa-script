# Native library build contract

This E02 Darwin fixture builds the same C implementation as both a static
archive and a shared dynamic library, then links and runs one client against
each. The shared client embeds `@loader_path` so runtime loading resolves next
to the executable rather than through an ambient `DYLD_LIBRARY_PATH`.

The public header marks `answer` as default-visible while targets compile with
hidden-by-default visibility. Successful shared-client linking and execution
therefore exercise the exported symbol and dynamic loader path. Both clients
must exit 0, print exactly `answer=42\n`, and emit no stderr.

`CMakeLists.txt` is the independent CMake reference and registers both clients
with CTest. `test/script_parity/native_libraries_launcher_test.elisascript` is
the public-launcher comparison harness: it runs configure, build, CTest, the
ElisaScript build recipe, and then each of the four produced clients in
separate build roots. It compares each static/shared process pair by exit
status, stdout, and stderr, and also checks the fixed expected bytes. The test
requires explicit validation reauthorization, the bounded test-wrapper marker,
and the pinned local compiler path; it is not safe or enabled for ad-hoc runs.
`build.elisascript` expresses compilation, archive creation,
shared linking, client linking, and execution as a dependency graph with
declared outputs and argv-only commands. It compiles separate static and
shared object files: both use C11, the same warning/visibility flags, and the
shared object additionally uses PIC, matching CMake's per-target compilation
settings. Its client-run nodes use the same 10-second timeout as the CTest
entries while retaining a separate longer timeout for compilation and linking.
It requires the caller to supply an
existing empty absolute build directory outside the repository and never
removes caller-owned paths. On graph failure, it reports the failed node,
exit status or missing declared output, and retained bounded stdout/stderr on
stderr. Its run nodes reject nonempty stderr as well as unexpected stdout.

Evidence is source-only: no compiler, CMake, CTest, or parity process has been
run. The fixture is Darwin-specific and not yet an E02 acceptance result.
