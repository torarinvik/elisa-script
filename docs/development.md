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
Character formatting likewise now returns `cstr` through all three helpers.
The existing one-byte value plus NUL is copied by `intern_small_string`;
conversion occurs only after that permanent-storage copy. Both character
wrapper type errors clear with no changed-prelude diagnostics. The bounded
build still exits 1 on other errors (5.23 seconds; sampled peak RSS
724,688 KiB); artifact: engine
`build/validation/elisascript-ddbc803d-char-cstr-build.log` and adjacent JSON.
Character formatting has not executed on this compiler.
Integer formatting now returns `cstr` through its three helpers. Both the
interned short-string and arena paths check that the writing `snprintf`
returns its previously measured length before publishing a terminated string;
the cast is confined to that NUL-producing boundary, matching upstream's
return type. The bounded build clears both integer forwarding-wrapper errors
and reports no diagnostics in the changed prelude helper. It still exits 1
on unrelated errors (3.93 seconds; sampled peak RSS 726,880 KiB). Artifact:
engine `build/validation/elisascript-ddbc803d-int-cstr-build.log` and JSON.
Integer formatting execution remains unverified on this compiler.
The three boolean string helpers now return `cstr`, matching upstream's
static-literal implementation and retaining the NUL-terminated type across
the forwarding wrappers. No casts or allocation changes were added. The two
boolean wrapper return mismatches clear in the bounded build; unrelated errors
still produce status 1 (6.24 seconds; sampled peak RSS 726,896 KiB).
Artifact: engine `build/validation/elisascript-ddbc803d-bool-cstr-build.log`
and adjacent JSON. No runtime execution is established by this result.
The vendored float formatter's marker scan now yields its exponent/decimal
indices as a loop-result tuple, retaining `source_length` for absent markers
and the last encountered index for repeated markers. This repairs two illegal
assignments to immutable locals using the Stage1 loop-expression form. The
bounded build has no diagnostics on the marker loop, but still exits 1 on
other compatibility errors (5.98 seconds; sampled peak RSS 726,896 KiB).
Artifact: engine `build/validation/elisascript-ddbc803d-marker-loop-build.log`
and adjacent watchdog JSON. Formatting behavior remains unexecuted.
The subsequent bounded build restores the missing `text_ascii_whitespace`
helper used by ASCII predicates and splitting (space or bytes 9–13).
All four undefined-helper diagnostics clear; the build still exits 1 after
8.65 seconds with sampled peak RSS 726,880 KiB. Its engine artifact is
`build/validation/elisascript-ddbc803d-text-helper-build.log` and adjacent JSON.

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

The view-to-string copy helper now preserves `cstr` through empty, short and
long NUL-producing copy paths; its three callers no longer cast the result
back to `u8&`. This boundary matches the actual terminated output. The bounded
compile reports no diagnostics on the changed helper/callers, but the runtime
entrypoint still has the same 31 diagnostics: this change establishes no
reduction in the remaining compiler failures. The build exits 1 normally in
11.53 seconds, sampled peak RSS 725,872 KiB. Engine artifact:
`build/validation/elisascript-ddbc803d-view-copy-build.log` and watchdog JSON.
Copy behavior remains unexecuted on the selected compiler.

Unsigned and floating-point scratch formatting now return `cstr` at their
NUL-producing boundaries. Unsigned formatting checks the writing `snprintf`
length; the float marker scan yields its boolean result with initial false,
retaining the existing formatting and `.0` suffix algorithm. In the bounded
build, runtime entrypoint diagnostics fall from 31 to 5. Remaining diagnostics
include three concat/slice return mismatches and two newly reached global
`perm_arena` borrow conflicts; they require explicit ownership review.
The after build exits 1 normally in 7.86 seconds, sampled peak RSS 726,960 KiB.
Artifact: engine `build/validation/elisascript-ddbc803d-numeric-cstr-fixed-build.log`
and watchdog JSON. The preceding `numeric-cstr-build` attempt compiled unchanged
source after an edit assertion failed; it is not evidence for this repair.
Numeric formatting execution remains unverified.

The permanent integer/character wrappers now use upstream's call-local
`trusted Unsafe.Alias` exception. Review found sequential arena descriptor
access: integer small-string/length-cache allocation goes through alloc_perm,
and character formatting ignores its arena argument before its permanent
copy. Returned strings refer to allocated storage, not the lent descriptor.
Comments identify these paths; exclusivity checks remain active elsewhere.
Both global-borrow diagnostics clear; runtime entrypoint diagnostics fall
from 5 to 3. The bounded compile still exits 1 on other errors (7.59 seconds;
sampled peak RSS 728,672 KiB). Engine artifact:
`build/validation/elisascript-ddbc803d-arena-alias-build.log` and watchdog JSON.
This establishes neither concurrent allocator safety nor an executed launcher.

Concat, scratch concat and string slice now accept optional `cstr` inputs and
return `cstr`, preserving that guarantee in unchanged-input return paths.
Copied paths convert only after writing the terminator or interning a copy;
size guards and slice clamping are retained. The bounded build clears all
three remaining runtime entrypoint diagnostics, with no diagnostics on these
functions. Other string-view carrier and source compatibility errors remain.
It exits 1 normally in 7.23 seconds, sampled peak RSS 726,944 KiB. Artifact:
engine `build/validation/elisascript-ddbc803d-concat-slice-build.log` and JSON.
These operations have not executed on the selected compiler.

The C-string view, view-slice and byte-array view constructors now use the
current upstream runtime's local carrier grants and extent checks. C-string
inputs retain `cstr`; invalid signed extents and malformed byte-array storage
return empty views before pointer arithmetic/indexing. The bounded build
clears all four runtime-string-fragment diagnostics, including three internal
carrier errors, while other launcher errors remain. It exits 1 normally in
8.59 seconds, sampled peak RSS 727,056 KiB. Engine artifact:
`build/validation/elisascript-ddbc803d-view-carrier-build.log` and JSON.
View behavior/lifetimes have not been runtime-qualified on this compiler.

The IR effect identity hash helper now has an IR-specific name, preventing
resolution to Ast's private same-named helper, and binds its cross-product
sum as one immutable expression. This preserves the limb formula: each masked
summand is at most 2^32−1, so their sum fits u64. All five ir_model diagnostics
clear in the bounded build; other launcher errors remain. It exits 1 normally
in 9.38 seconds, sampled peak RSS 530,128 KiB. Engine artifact:
`build/validation/elisascript-ddbc803d-ir-hash-build.log` and watchdog JSON.
Runtime effect identity behavior remains unverified on this compiler.

Allocator return paths now retain mutable pointer qualifiers through fixed
buffer allocation, arena allocation/reallocation and arena formatting. The
free-list split reference is initialized from its computed in-block address
with explicit pointer effects, replacing an invalid zeroed non-null reference.
The bounded compile clears all eight arena/heap diagnostics and reports none
in either fragment; unrelated launcher errors remain. It exits 1 normally
in 11.50 seconds, sampled peak RSS 635,776 KiB. Engine artifact:
`build/validation/elisascript-ddbc803d-allocator-refs-build.log` and JSON.
Allocator behavior has not executed on the selected compiler.

Concurrency allocation now preserves malloc's mutable pointer through return;
AtomicCell constructs its generic slot from the supplied value rather than
zeroing a potentially non-null type. Both associated diagnostics clear in
the bounded compile, leaving nine concurrency diagnostics. The generic worker
result seed still needs completion-protocol review; it was not replaced by
unchecked uninitialized typed storage. The build exits 1 normally in
20.92 seconds, sampled peak RSS 617,600 KiB. Engine artifact:
`build/validation/elisascript-ddbc803d-concurrency-init-build.log` and JSON.
Runtime concurrency behavior remains unverified on the selected compiler.

Platform concurrency wrappers now explicitly grant pointer conversion where
Win32 opaque handles are recovered for lock/condition operations and where
pool worker state/record pointers are recovered from submitted handles.
Comments identify Win32 initialization and the nonzero record uintptr
round-trip as the source of those handles. Eight conversion diagnostics clear,
leaving only the generic worker-result seed error in the concurrency fragment.
The bounded compile exits 1 on remaining errors in 5.25 seconds, sampled peak
RSS 658,880 KiB. Engine artifact:
`build/validation/elisascript-ddbc803d-concurrency-casts-build.log` and JSON.
No Windows execution or pool synchronization behavior is established.

Generic worker results now use untyped allocated storage instead of an invalid
zeroed R. The worker writes R before release-storing completed=1; result take
requires an acquire load observing completion before its typed read. Existing
join/pool-wait and reference-count release paths remain. Current compiler
codegen_atomic.elisa recognizes both atomic[T] and AtomicSlot[T], supporting
the ordered publication calls. Conversions are confined to two documented
result-storage helpers. The bounded compile clears the last concurrency
fragment diagnostic and reports none in that fragment; other launcher errors
remain. It exits 1 normally in 9.65 seconds, sampled peak RSS 587,088 KiB.
Engine artifact: `build/validation/elisascript-ddbc803d-worker-result-build.log`
and JSON. Native worker execution and adversarial completion controls remain
required before treating this synchronization path as qualified.
