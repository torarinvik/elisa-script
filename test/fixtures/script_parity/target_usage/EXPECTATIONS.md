# Target-usage propagation contract

This Darwin-specific E03 fixture tests CMake-compatible
public/private/interface propagation through an interface target, a private
static dependency, a public static library interface, and a final executable.
It is a deliberately small representative, not an inventory of any current
project.

`api` exports an include directory, compile definition, compile option, link
library, and link option. `core` consumes `api` publicly and `helper` privately.
It has private include/definition/option requirements and separately exports
its public header, ABI definition, and compile option. Because `core` is static,
its private `helper` link dependency must still reach the final executable's
link closure without leaking any helper or private-core compile settings.

The C sources make those relationships observable: missing propagated
requirements fail compilation or linking; leaked private requirements fail
the consumer compilation; and the executable checks the linked behavior. Both
build routes must produce an executable that exits 0, writes exactly
`usage=32\n` to stdout, and writes nothing to stderr.

`build.elisascript` resolves the typed `BuildUsageTarget` graph, materializes
resolved compile/link entries with the shared owned argv adapters, creates raw
argv for archiver/run actions, and submits all seven steps through the shared
`BuildUsageGraphPlan` with declared outputs. Archive, link, and run children
use an explicit replacement environment. Compiler children inherit the
controlled environment supplied by the parity launcher because the standard
compilation database cannot represent a replaced environment. It requires an
existing absolute empty non-symlink build directory outside the repository.
No command is passed through a shell.
Before execution it selects the three compiler actions from that same validated
plan, renders their exact tokenized argv into bounded `compile_commands.json`
records, and writes the database into the fresh build directory. Archive, link,
and run actions are intentionally excluded from the translation-unit database.
The usage-dependency edges propagate compile/link interfaces and contribute
concrete static/shared library artifacts to the link closure. `core` exports
its private static dependency `helper` as a link-only entry, which the final
executable consumes as a normal link input alongside `core` and the `m` system
library propagated through the public `api` interface. The candidate does not
add duplicate explicit `LinkLibrary` requirements for either target, so the
fixture depends on correct target-artifact and private dependency-edge
propagation.
Resolved link entries preserve target-artifact identity separately from
literal linker names, so equal spellings such as a target named `m` and the
system library `m` cannot be deduplicated or emitted using the wrong form.
`LinkLibrary` requirements explicitly choose `SearchName`, `Path`, or
`LinkerArgument`; the model rejects mismatched spellings, and the candidate
lowers each form without guessing. Absolute/relative paths and prefixed
linker items remain literal argv entries; relative paths are prefixed with
`./` to prevent option/response-file interpretation by the compiler driver.

`test/script_parity/target_usage_launcher_test.elisascript` runs the CMake
configure/build/CTest route and the candidate build in separate fresh roots,
then compares executable status and both output streams. It is gated on
explicit validation reauthorization, the bounded-test-wrapper marker, and the
pinned local compiler path. The fixture is source-only and is not an E03
acceptance result.
