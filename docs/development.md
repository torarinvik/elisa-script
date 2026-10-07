# Elisascript development builds

> **2026-09-15 native launcher update:** The engine task authorized bounded native
> integration work, and its check now passes. See [the validation record](engine-check-validation.md)
> for compiler fixes, installation, and test evidence. The historical pinned wrappers
> and their broader validation hold described below were not reopened.

## Engine launcher compatibility repair — 2026-10-08

The engine's bounded integration attempt with immutable Stage1 `ddbc803d`
identified argument-view invalidation in all five process paths in
`src/ir/interpret.elisa`. Each path now validates and builds `owned_arguments`
completely before collecting element pointers into `argv`. Argument order,
text/NUL validation, executable pointer and final NULL slot are preserved;
the owning storage remains in the enclosing scope through the foreign call.

The engine watchdog's before/after builds both completed with status 1.
The repair removes all 25 `argv` storage-dependency invalidation diagnostics.
The after build took 3.61 seconds with sampled peak RSS 725,792 KiB under a
1,572,864 KiB / 180-second bound. This is partial compiler compatibility
evidence, not a runnable launcher or process-behavior validation. Other
vendored-runtime, pointer-effect and allocation-lifetime diagnostics remain.
Logs are in the engine checkout under
`build/validation/elisascript-ddbc803d-argv{,-fixed}-build.log`, with watchdog
JSON reports beside them. The historical wrapper validation hold remains.

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

The latest Elisa-compiler remote head was read-only verified on 2026-09-24 as
`ec4c7b93e6b0ef849dc5001df964f860c485018b` (`Protect shared arena cache across
threads`). The sibling `../Elisa-compiler` checkout is at
`2e9d5bf5afb26aabbec15d1059b8f4c2abde82fd` and has an uncommitted change in
`src/semantic/resolve_generic_call_types.elisa`; it is not treated as a clean,
reproducible latest-source checkout. The remote-tip check is provenance only:
no fetch, checkout, build, or compiler invocation was performed.

`vendor/elisa-compiler` remains an adapted snapshot, not a mirror of that remote
tip. It includes the focused lexer buffer-return optimization, compatible
semantic lookup-index fast paths, and selected correctness fixes described by
its source history; newer arena-cache, allocator, and ABI/backend changes have
not been imported. Do not call the vendor tree current with upstream until a
clean source revision is reconciled and each change is reviewed for compatibility.
The separate Elisa-core source and the guarded local compiler path remain
subject to the validation hold above; source freshness does not authorize a run.

The separate Go Elisa-core source checkout currently visible (read-only
rechecked 2026-09-20) is clean at revision
`90228b6ff38091324f1f19ec7b81bbd2f39825bf` on its `main` branch at
`/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/Elisa-core`. It
includes nested-expression effect inference and generic private-field
validation fixes. It is five commits ahead of its checked `origin/main` at the
time of observation. The explicitly safety-pinned `structpy-tree/compiler/bin/elisac`
path is absent in this workspace; the ignored executable in the Elisa-core
main-worktree was built from an older revision with `vcs.modified=true`, so it
is neither a reproducible build of this revision nor an authorized validation
target. Do not substitute it into a wrapper or build anything while the
validation hold is active. After explicit reauthorization, create an isolated
clean checkout of the exact Go compiler revision, build an executable there,
record its digest in `docs/validation-baseline.md`, and update the wrapper pin
before any fixture run.

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
checkout at the exact canonical StructPy executable path
`/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/structpy-tree/compiler/bin/elisac`
and reads the Go build metadata embedded in `elisac`; the embedded VCS
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
uses a 524,288 KB RSS ceiling with a 120-second timeout by default. The RSS
limit may be lowered with `ELISASCRIPT_RSS_LIMIT_KB` but cannot be raised above
524,288 KB (512 MiB); time and log limits can be changed explicitly with
`ELISASCRIPT_TIME_LIMIT_SECONDS` and `ELISASCRIPT_LOG_LIMIT_BYTES`. All three
values must be positive decimal integers with at most 10 digits; malformed,
zero, and overlong values are
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
After escalation, each wrapper keeps its session leader unreaped and repeats
group `KILL` until a complete process snapshot proves no live group members
remain. If ownership or quiescence cannot be proven, it sets the emergency
latch and retains the validation lease rather than treating cleanup as complete.

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
