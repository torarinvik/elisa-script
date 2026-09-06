# Elisascript development builds

The current pinned identity and host/bootstrap metadata are recorded in
[`docs/validation-baseline.md`](validation-baseline.md). Refresh that record
before changing the compiler pin or treating any validation result as
reproducible.

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
`ELISASCRIPT_RSS_LIMIT_KB`, `ELISASCRIPT_TIME_LIMIT_SECONDS`, and
`ELISASCRIPT_LOG_LIMIT_BYTES`. All three values must be positive decimal
integers; malformed or zero values are rejected before any compiler process is
created. The log ceiling defaults to 64 MiB and bounds the temporary compiler
diagnostic file using the same polling model as the RSS/time watchdog. Each
fixture argument must be an existing `.elisascript` regular file. The wrapper installs signal/exit
cleanup for its temporary log and owned compiler tree, and clears the child PID
after `wait` so cleanup cannot act on a reused PID. Tree termination snapshots
the owned PID set before signaling the root, so children that become reparented
after the root exits still receive the forced second signal. The lowering and executable
wrappers also serialize validation through an atomic lease directory under
`${TMPDIR:-/tmp}`. The lease records the owner PID and `ps` start identity; a
live owner with an untrusted or reused identity fails closed, while a dead owner
can be reclaimed. A missing readiness marker is never removed automatically,
which avoids racing a worker that is still publishing its identity. This lease
prevents two bounded workers from competing for the host's memory. Both
wrappers set `umask 077` before creating lease metadata or temporary logs, and
the lease does not turn the polling RSS guard into an instantaneous OS-enforced
cap. `scripts/stop_bounded_validation.sh` is the scoped emergency stop: it
atomically creates the directory `${TMPDIR:-/tmp}/elisascript-validation.disabled`, verifies the live lease
owner's PID, start identity, and wrapper command, then terminates only that
wrapper's snapshotted process tree. Any RSS, timeout, or diagnostic-log guard
trip also sets this latch. Both validation wrappers refuse to relaunch while
the latch exists; remove it manually only after reviewing the failure and
deciding to reauthorize a smaller bounded run.

Run the compiler-free wrapper audit before reviewing a validation change:

```sh
scripts/check_validation_wrappers.sh
```

This checks the disabled-by-default gate, StructPy compiler pin, process-tree
RSS guard, identity-bound lease, and emergency-stop ownership without launching
a compiler.

Run `scripts/check_resource_policy.sh` alongside the wrapper audit when changing
runtime limits. It is also compiler-free: it checks that the shared policy and
usage records cover every declared budget dimension and that both interpreter
and direct-bytecode execution return the inherited step policy without starting
either backend.

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
