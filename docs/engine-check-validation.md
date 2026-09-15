# Native launcher validation — 2026-09-15

## Result

**The native ElisaScript launcher replaces the engine shell check successfully.**
The installed command passed the entity runtime tests and Elisa Proof: 15 obligations
proved, 15 certificates replayed, zero failures, diagnostics, or replay gaps.
`elisa-engine/test/check_workflow.py` passed all ten comparisons against the original
shell workflow, including child failures at every phase, output on both streams,
paths with spaces, PATH discovery, missing tools, empty overrides, and default prover
lookup. Each comparison runs outside the copied project's directory.

The `.elisascript` uses shell-free argument vectors and explicitly relays captured
stdout/stderr. Output is buffered until each child completes. The native process
adapter's existing timeout and output limits still apply; this is not a general
replacement for every shell behavior.

## Installation and identities

- Launcher source: `src/driver/elisascript.elisa`, through `src/ir/execution.elisa`.
- Installed command: `~/.local/bin/elisascript`, a symlink to
  `elisa-script/.validation/native/elisascript`.
- Launcher SHA-256: `143b22a691f88f5d17eadf60b2f5bbad97981e1928feed13ae36ab047e8b91e5`.
- Compiler worktree: `/Users/torarinvikbjarko/Documents/Coding Projects/Elisa Projects/elisa-script-compiler`.
- Compiler branch: `codex/elisascript-native-integration`, based on `0d92a608`.
  Changes are uncommitted and isolated from the main compiler checkout's other work.
- Patched compiler: `build/elisac-native-integration` in that worktree.
- Patched compiler SHA-256: `a9f93d2a26d78deb8dc9f4aeb24eb73381fdf5dbbf96f622064b5a2155b5195e`.
- Bootstrap: preserved installed stage1 snapshot of `0d92a608`, taken
  2026-09-15T14:54:44Z, under the engine's `build/script-validation/stage1-snapshot`.
  Its SHA-256 is `2d688a83f0abaff3899fe21d83dcb3b916a114ed47113ff5284e5db5ad0654bb`.

The engine's documented PATH-based command was verified with the installed stage1
compiler as well as with the preserved snapshot. No compiler changes were installed
into the user's stage1 release. Earlier bootstrap exploration triggered a checkout
hook that refreshed installed stage0 to revision `7900a37a`; later worktree creation
explicitly disabled checkout hooks.

## Changes needed

The native compiler now registers module-scoped externs with the correct owner;
binds fieldless caught errors; rethrows those values; and resolves qualified catch
callees without losing their module. Diagnostics retain up to 512 declined bodies
so integration failures can be attributed. Compiler fixtures cover same-named externs
in different modules, catch statement/expression bindings and scope restoration,
rethrows, and same-named fallible callees in different modules. Payload-bearing
catch-all error values were not added by this work.

ElisaScript's execution include graph now builds independently of unrelated tooling
models. Source fixes cover malformed syntax, mutability, explicit reference reads,
AST storage provenance, borrowed array headers, fallible-call lowering forms, explicit
host-ABI defaults, and pointer narrowing. Source/IR/execution data that escapes a
helper is allocated in the caller's region. The builtin argument checker now accepts
`sview` as text, while retaining rejection of numeric process input.

## Runtime evidence

- `test/driver/argv_probe.elisascript`: exit 23 with a spaced argument and an empty one.
- `test/driver/process_capture_text.elisascript`: exit 0; literal and typed text,
  exact captured output, and child failure status checked.
- `test/driver/process_capture_invalid_input.elisascript`: `--check` exits 1 with
  the expected argument-3 type diagnostic.
- `test/compiler_compat/cli_model.elisa`: native exit 0; options, arguments, and
  invalid color rejection checked.
- Engine script `--check`: exit 0.
- Installed engine check: exit 0, 15/15 obligations and replay certificates.
- Engine shell comparison: 10/10 cases passed.

Full ElisaScript and compiler suites were not run. Historical pinned wrappers
remain unchanged; this record does not claim their gates passed. The native launcher
still only implements run/check modes, as before.

## Bounded build evidence

The final launcher build used `-O0 -emit exe`, finished in 87.08
seconds, and reached 1255280 KiB sampled process-tree RSS. The guard
allowed 1572864 KiB, 180 seconds, and 8 MiB of log output. This sampled watchdog is
reactive, not hard memory containment. Initial 512 MiB builds were stopped rather
than allowed to run unbounded.

Logs, watchdog manifests, compiler snapshots, and the generated proof report remain
in the sibling engine's ignored `build/` tree. Relevant logs are
`launcher-text-checker-fixed.log`, `engine-parity.log`, `engine-real-check.log`, and
`installed-engine-check.log`, with their `.json` manifests. The proof report is
`elisa-engine/build/entity-id-proof.json`.

To rebuild with the retained local artifacts, from `elisa-engine`:

```sh
ELISA_STAGE1_BIN="$PWD/../elisa-script-compiler/build/elisac-native-integration" \
CHECK_RSS_KB=1572864 CHECK_SECONDS=180 \
python3 build/script-validation/bounded.py build/script-validation/rebuild.log \
  bash build/script-validation/stage1-snapshot/scripts/elisac_stage1.sh \
  -O0 -emit exe -o build/script-validation/elisascript \
  ../elisa-script/src/driver/elisascript.elisa
python3 test/check_workflow.py build/script-validation/elisascript
```

The watchdog and snapshot in that command are retained local validation artifacts,
not portable build dependencies. Rebuilding elsewhere requires the corresponding
compiler fixes and a matching runtime/toolchain.
