# Elisascript development builds

The current pinned identity and host/bootstrap metadata are recorded in
[`docs/validation-baseline.md`](validation-baseline.md). Refresh that record
before changing the compiler pin or treating any validation result as
reproducible.

Use the compiler built from the local Elisa-core checkout when changing stage0 or
stage1 compiler code. Validation is currently fail-closed after an RSS incident:
the checked-in process-group watchdog refuses to launch unless the user explicitly
sets `ELISASCRIPT_VALIDATION_REAUTHORIZED=1`. Do not set that override without a
small, bounded repro and an explicit decision to resume validation. When validation
is authorized, use the local compiler path and watchdog:

The current validation state remains suspended. The examples below are reference
commands, not authorization to run them; the environment variable is a manual gate,
not standing approval. Do not launch a compiler or test wrapper unless the user
explicitly reauthorizes validation in the active task.

The newest source-only compiler snapshot currently available is
`/private/tmp/elisa-compiler-debugger-c605b3fa` at
`c605b3faa516de7b2f4945a9ac4ccb21d78ae2e0`; it contains the latest lowering
optimizations but has no built executable. Do not substitute it into a wrapper
or build it while the validation hold is active. After explicit
reauthorization, build an isolated executable from that clean snapshot, record
its exact revision and digest in `docs/validation-baseline.md`, and update the
wrapper pin before any fixture run.

```sh
ELISASCRIPT_VALIDATION_REAUTHORIZED=1 \
ELISA_LOCAL_COMPILER="/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/structpy-tree/compiler/bin/elisac" \
scripts/run_bounded_lowering.sh test/driver/argv_probe.elisascript
```

The local StructPy checkout keeps compiler changes isolated from the installed
release at `~/.elisac/elisac` and the Elisa-core main-worktree binary; do not use
either installed or main-worktree binaries for stage0/stage1 validation. The
process-group RSS-and-time watchdog is sampled and reactive, not a hard resource
containment boundary: fast allocations may overshoot between samples, and a
double-forked process that leaves the group and reparents can evade both the group
and descendant snapshots. It can detect and terminate observed breaches but
cannot guarantee the host-safe ceiling. A virtual-memory limit alone is not
sufficient. The wrapper deliberately uses `-emit lowered`
first; do not relaunch a large executable fixture after an RSS incident until a
smaller bounded repro has stayed under the guard. The same `ELISA_LOCAL_COMPILER`
setting should be used for the lowering,
interpreter, bytecode, source-loader, parser, lexer, semantic, and differential
test suites. Rebuild the local Elisa-core compiler first when its stage0 or stage1
sources change, then rerun the Elisascript suites from this checkout.

Resolve the compiler identity and keyed output directory before a validation
session with `scripts/validation_identity.sh`. It requires a clean pinned source
checkout and reads the Go build metadata embedded in `elisac`; the embedded VCS
revision must exactly match the checkout and report `vcs.modified=false`. This
detects a stale binary or one built from modified sources without launching
`elisac`. It also records the executable SHA-256, optimization/target/mode
configuration, and a derived output key under `.validation/`; that directory is
ignored and must not be used as a substitute for a validation result. Set
`ELISASCRIPT_VALIDATION_OUTPUT_ROOT` to place keyed logs and artifacts in a
reviewed external directory. The helper does not build or launch the Elisa
compiler. The historical `validation-baseline.md` is stale after compiler-source
changes; refresh its identity only in an explicitly authorized build/validation
session.

For a reusable guard instead of an inline shell function, run
`scripts/run_bounded_lowering.sh test/driver/argv_probe.elisascript` from
this repository after explicit reauthorization. It accepts one or more small
fixtures, refuses any compiler path outside the pinned StructPy checkout, and
uses a 524,288 KB RSS ceiling with a 120-second timeout by default. The limits
can only be changed explicitly with
`ELISASCRIPT_RSS_LIMIT_KB`, `ELISASCRIPT_TIME_LIMIT_SECONDS`, and
`ELISASCRIPT_LOG_LIMIT_BYTES`. All three values must be positive decimal
integers with at most 10 digits; malformed, zero, and overlong values are
rejected before any compiler process is created. The log ceiling defaults to 64
MiB and cannot exceed the 1 GiB retained evidence budget per
compiler/configuration identity. Both are monitored by
polling, not a hard file-size quota: a fast writer can overshoot before it is
stopped. Before launch, each primary fixture must pass the wrapper's regular,
non-symlink path check. The wrapper copies at most 65,537 bytes into a private
temporary sibling file in the source directory, rejects it if it exceeds
65,536 bytes, and launches the compiler on that exact captured file. Keeping
the snapshot beside the original preserves the relative base for `include`.
The captured size and both the original and snapshot paths are recorded in the
manifest. This prevents a post-check replacement or growth from giving the
compiler a larger primary source; it is not a bound on transitive includes or
compiler memory, nor a security boundary against a hostile concurrent in-place
writer while the copy is being made. Keep include graphs and repro work small
as well. Successful, failed, and interrupted runs retain a combined
stdout/stderr log and sidecar manifest under
`.validation/<configuration-key>/logs/` (or the configured output root). The
manifest records compiler identity, limits, source path as hex, admitted
primary-source size, the captured snapshot path, process ownership, observed
RSS samples, exit status, and guard results. Old evidence is never pruned
automatically; review it before removing it to make room. The wrapper installs
signal/exit cleanup for its owned compiler tree and
clears the child PID after `wait` so cleanup cannot act on a reused PID. Each
compiler is launched by an absolute `setsid` helper in a private process group.
The watchdog samples RSS for processes in that group and the currently
discoverable descendants, refuses to continue if the compiler inherits the
wrapper's group, and sends group `TERM` then `KILL` plus a snapshotted descendant
fallback. A detached, reparented process can escape both observations and cleanup;
record this limitation in any future synthetic watchdog evidence. The lowering and executable
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
wrapper's snapshotted process tree and the private child groups represented in
that snapshot, never the wrapper's own group. Any RSS, timeout, or diagnostic-log
guard trip also sets this latch. Both validation wrappers refuse to relaunch while
the latch exists; remove it manually only after reviewing the failure and
deciding to reauthorize a smaller bounded run.

Run the compiler-free wrapper audit before reviewing a validation change:

```sh
scripts/check_validation_wrappers.sh
```

This checks the disabled-by-default gate, exact StructPy compiler pin,
best-effort process-group RSS guard, private-session launch requirement,
identity-keyed evidence retention, identity-bound lease, and emergency-stop
ownership without launching a compiler.

Run `scripts/check_resource_policy.sh` alongside the wrapper audit when changing
runtime limits. It is also compiler-free: it checks that the shared policy and
usage records cover every declared budget dimension and that both interpreter
and direct-bytecode execution return the inherited step policy without starting
either backend.

Executable fixtures use the matching process-group guard:

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
