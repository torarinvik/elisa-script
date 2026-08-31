# Elisascript development builds

Use the compiler built from the local Elisa-core checkout when changing stage0 or
stage1 compiler code. Validation is currently fail-closed after an RSS incident:
the checked-in process-tree watchdog refuses to launch unless the user explicitly
sets `ELISASCRIPT_VALIDATION_REAUTHORIZED=1`. Do not set that override without a
small, bounded repro and an explicit decision to resume validation. When validation
is authorized, use the local compiler path and watchdog:

```sh
ELISASCRIPT_VALIDATION_REAUTHORIZED=1 \
ELISA_LOCAL_COMPILER="/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/structpy-tree/compiler/bin/elisac" \
scripts/run_bounded_lowering.sh test/ir/elisascript_lowering_test.elisa
```

The local StructPy checkout keeps compiler changes isolated from the installed
release at `~/.elisac/elisac` and the Elisa-core main-worktree binary; do not use
either installed or main-worktree binaries for stage0/stage1 validation. Keep
validation bounded with the process-tree RSS-and-time watchdog that terminates
the compiler before its total RSS exceeds the host-safe ceiling; a virtual-memory
limit alone is not sufficient. The wrapper deliberately uses `-emit lowered`
first; do not relaunch a large executable fixture after an RSS incident until a
smaller bounded repro has stayed under the guard. The same `ELISA_LOCAL_COMPILER`
setting should be used for the lowering,
interpreter, bytecode, source-loader, parser, lexer, semantic, and differential
test suites. Rebuild the local Elisa-core compiler first when its stage0 or stage1
sources change, then rerun the Elisascript suites from this checkout.

For a reusable guard instead of an inline shell function, run
`scripts/run_bounded_lowering.sh test/ir/elisascript_lowering_test.elisa` from
this repository after explicit reauthorization. It accepts one or more small
fixtures, refuses any compiler path outside the pinned StructPy checkout, and
uses a 524,288 KB RSS ceiling with a 120-second timeout by default. The limits
can only be changed explicitly with
`ELISASCRIPT_RSS_LIMIT_KB` and `ELISASCRIPT_TIME_LIMIT_SECONDS`.

Executable fixtures use the matching process-tree guard:

```sh
ELISASCRIPT_VALIDATION_REAUTHORIZED=1 \
ELISA_LOCAL_COMPILER="/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/structpy-tree/compiler/bin/elisac" \
scripts/run_bounded_test.sh test/driver/elisascript_bounded_test_smoke.elisascript
```

This wrapper invokes `-emit test` and applies the same RSS and timeout limits.
Keep executable repros small and bounded; do not send a large interpreter fixture
through the test emitter after an RSS incident.

Elisascript source files use the `.elisascript` extension. The canonical source
loader and runner tests should be the first checks after a compiler rebuild because
they exercise parsing, semantic checking, lowering, verification, and execution
through the same local compiler path.
