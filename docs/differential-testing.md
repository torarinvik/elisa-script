# Differential testing in Elisascript

Differential testing is a primary Elisascript use case: validate that an Elisa port
has the same observable behavior as its original C, C++, Python, Rust, or other
implementation. It must be supported as a typed testing model, not just as two
subprocess calls followed by string comparison.

## Core model

```elisa
struct DifferentialCase[I, O]:
    name: Text
    inputs: Generator[I]
    reference: Runner[I, O]
    candidate: Runner[I, O]
    compare: Comparator[O]


@differential_test
def z80_step_matches_original() -> DifferentialCase[CpuInput, CpuObservation]:
    return DifferentialCase{
        name: "z80-step",
        inputs: CpuInput.generate(),
        reference: Process.runner(exe"original-z80", CpuProtocol),
        candidate: Elisa.runner(z80_step),
        compare: CpuObservation.exact()
    }
```

The framework runs both sides from the same generated or recorded input and
compares structured observations.

The concrete first case boundary is `EsDifferential.DifferentialCase`. It binds a
reference runner and candidate runner to a `DifferentialWorld` containing the
working directory, typed fixture files, ordered environment, argv, text or binary stdin, locale,
timezone, and seed. A fixture is explicitly `DifferentialWorldFileKind.Text` or
`DifferentialWorldFileKind.Bytes`; byte fixtures own their bounded `darray[u8]`
payload, so NULs and other binary data never cross a C-string boundary. Mixed
text/byte payloads and unknown fixture kinds are rejected rather than guessed.
Fixture `mode` accepts only ordinary permission bits (`0000` through `0777`);
setuid, setgid, and sticky bits are rejected because they are host identity
policy rather than portable test input. The separately fingerprinted
`executable` marker is canonical metadata: it must be true exactly when any
owner/group/other execute bit is present in `mode`. It does not claim that the
current host identity can execute the file. A physical materializer must create
with restrictive permissions, apply the exact admitted mode after writing, and
read the mode back; the process umask must not silently alter fixture identity.
Filesystem snapshots derive the executable marker from regular-file mode bits,
not from directory or symlink permissions.
World binary stdin uses the same explicit mode and bounded owned-byte rule as
binary files, and its bytes participate in the world fingerprint. `validate_differential_case` validates both nested runners, rejects NULs, duplicate
fixture paths, oversized world data, invalid engine or artifact policies, comparator
policy, and preserves the nested runner issue kind.
Each case also owns a closed `DifferentialObservationSchema`. Its sites are
strictly sorted by nonzero trace ID and declare a root `DifferentialValueKind`
plus minimum/maximum occurrence counts. Every emitted trace must be declared,
its root kind must match, and every site's count must fall in range. An empty
schema therefore means “no observations are allowed.” The schema is capped at
65,536 sites and each maximum count is bounded by the runtime observation
ceiling. This first version checks root kinds only; recursive aggregate shapes
remain a later extension.
A case may also set `timeout_steps` and `max_output_bytes` as shared ceilings for
both sides. Zero means “inherit this side's runner value”; a nonzero case ceiling
is combined with each runner by taking the smaller value, so case policy can
narrow but never expand a runner's own budget. `prepare_differential_case_runner`
validates the complete case and returns the selected side's runner with those
effective limits while preserving its arguments, handlers, environment, stdin,
and other adapter configuration. Call it separately for `DifferentialCaseSide.Reference`
and `DifferentialCaseSide.Candidate` before execution. It prepares limits only:
it does not materialize or merge `DifferentialCase.world` into runner settings.
The execution helpers accept a runner rather than a whole case, so passing the
original runner directly intentionally bypasses case-level ceilings; pass the
prepared runner to the adapter.
The shared numeric hard ceiling for timeout values is the runtime's default
maximum step budget. This is a VM step limit for in-process Elisascript runners,
but a bounded wait-poll count for native process runners; those units are not
wall-clock-equivalent. A case limit cannot raise the runner's configured timeout
(whose runner default is one), so callers should configure runner budgets first
and use case values only to tighten both sides. For external process runners,
`max_output_bytes` is one combined budget across stdout and stderr. Both
temporary streams are checked while the child is being polled and again
together before either is materialized into the run result. In-process
Elisascript runners also aggregate stdout and stderr writes, and the VM admits
each complete write against the remaining budget before sending bytes to the
host stream. Those console writes are bounded but are not yet captured into
`DifferentialRun.stdout`/`stderr`, so stdout parity still requires a process
adapter or a future captured-console boundary. Child-process captures inside
the reference interpreter charge both channels to the same aggregate runtime
ledger before allocating each retained channel. The direct bytecode path checks
captured process output against its aggregate ledger after the capture
instruction returns; a rejected capture can therefore temporarily materialize
more than the combined ceiling, up to the per-process stream guards.
Lower-than-default case budgets select the reference interpreter, so
case-narrowed captures use its pre-allocation accounting.
A complete world is also subject to an aggregate payload ceiling across its
working-directory/locale metadata, stdin, argv, environment, fixture paths, and
fixture bytes/text; length-only admission runs before NUL/duplicate/path scans,
and fixture paths have an explicit host-safe length ceiling before hashing or
filesystem materialization.
The aggregate helper rejects an already-over-limit total before subtracting the
remaining world capacity, and nested array/map comparison pools prove their
start index before subtracting the encoded value count.
Case names, runner names, oracle names, and serialized manifest identity fields repeat their
own metadata-length admission before any NUL scan. This keeps direct helper
calls fail-closed even when they bypass the ordered top-level case validator.
A validated case can produce a `DifferentialArtifactManifest` with case/runner
identities, seeds, engine requirement, artifact policy, a deterministic
fingerprint of the complete validated world (including fixture kind, bytes, mode,
and executable bit), a complete comparator policy, a SHA-256 digest of the
canonical observation schema (including the empty schema), and an optional
verified-module fingerprint/digest;
`canonical_differential_artifact_manifest_bytes` emits a bounded versioned `ESDF`
sidecar and `differential_artifact_manifest_fingerprint` provides a deterministic
correlation key. Version 2 adds the world fingerprint, version 3 adds text
comparison, map ordering, and exact float-tolerance bits, version 4 adds the
verified-module digest words, and version 5 binds the observation-schema digest.
The borrowed decoder continues to admit version-1 through version-4 manifests
for explicit migration. It validates magic, version, lengths, enum ordinals,
float payloads, and trailing bytes before exposing borrowed metadata; truncated
or malformed sidecars fail closed. Adapters remain responsible for materializing
the separate worlds and writing the complete output artifact.

The first shared comparison primitive is `EsDifferential.compare_differential_runs`.
It compares run outcome, exit status, named error, stdout, stderr, the typed return value,
observation count, and then each `(trace, value)` pair in that fixed order. It returns a typed
`DifferentialComparison` describing the first difference, including the relevant
text or values; identical runs return `DifferentialDifferenceKind.Equal`. The
comparator is implemented as an explicit Elisa state machine, so it cannot skip a
comparison phase or silently continue after a mismatch.
This low-level comparator intentionally has no case context, so it cannot detect
two runs that omit the same required observation. Use
`compare_differential_case_runs(case, reference, candidate)` for case-level
claims: it first preserves the ordinary comparison's first-difference order,
then validates both observation streams against the case schema. A violation
returns `DifferentialDifferenceKind.ObservationContract`; an invalid case is
reported as `DifferentialDifferenceKind.CaseInvalid`. These new report kinds
use ESCR version 3 while version-2 reports remain readable.
The library currently exposes single-run adapters and has no paired case
orchestrator. A host adapter making a case-level parity claim must call the
case-aware comparator after both prepared sides have produced runs. The replay
lifecycle compares while the captured runs are retained, then requires world
restoration before exposing the comparison artifact or completing the session.
The generic captured-run shrinker remains case-agnostic; it cannot prove a case
schema without receiving the case itself.

Process invocations also distinguish text stdin from an owned binary stdin buffer.
`stdin_binary` is required for byte payloads, mixed text/byte inputs are rejected,
and the same 64 MiB input ceiling applies before a child is launched. The host
adapter writes the bounded byte buffer by length, so embedded NULs and other
binary values never pass through a C-string conversion.
Before host execution, each `DifferentialProcessInvocation` is also adapted to
`EsProcess::ProcessCommand`. The shared validator rechecks the executable, ordered
argv, working directory, flattened environment names/values, explicit capture modes,
and failure policy using `error[ProcessCommandError]`; a direct adapter caller cannot
bypass duplicate-environment or aggregate terminated-byte admission. Binary stdin
remains an explicit length-delimited side channel rather than being misrepresented as
shell text. This keeps native and legacy-language oracle runners on the same typed
shell-free command boundary.
After the child is reaped and both streams are admitted, the adapter materializes
`EsProcess::ProcessResult` so a normal exit and signal death retain distinct typed
outcomes before conversion to the differential artifact. Spawn, timeout,
cancellation, output-limit, and host-I/O failures remain typed
`DifferentialRunnerError` paths until their corresponding terminal-result
materializers are wired into the host supervisor.
The runner's optional `working_directory` is admitted separately as a POSIX
pathname: non-empty values must fit the shared 4 KiB path envelope before any
NUL scan, aggregate C-string accounting, or child-side `chdir`. Executable,
entry, argv, and environment text retain the broader 64 MiB process-text
ceiling because they are not filesystem path operands; an oversized working
directory returns the existing typed `TooMuchProcessText` validation issue.
The shared process-text field predicate also rejects argument and environment
vectors above their one-million-entry caps before scanning or materializing any
field, so callers cannot reuse it as a fail-open preflight. Runner validation
checks those vector counts first, preserving the typed `TooManyArguments` and
`TooManyEnvironmentEntries` diagnostics before field-length admission.

The interpreter and direct-bytecode engine cap ordered `observe` events at one
million per run. Crossing that shared budget raises `InterpretError.OutputLimit`
before the next event is appended; differential adapters therefore receive a
bounded trace rather than an implicit unbounded memory commitment. The runtime
adapter also rejects externally supplied observation snapshots above the same
budget before converting any element into its owned comparison pools.

Observation and return values include `Void`, `Bool`, `Int`, exact `Float`, `Text`, recursive
`Array`, `Map`, and structured `ProcessCapture` kinds. Arrays
use a flat, owned value pool (`DifferentialRun.values`) with `(array_start,
array_count)` slices; maps use interleaved `(key, value)` pairs with
`(map_start, map_count)`, so nested observations remain deterministic without
borrowing an interpreter's runtime storage. `append_differential_observations_from_runtime`
performs that conversion and rejects out-of-bounds snapshots through
`DifferentialRunnerError`. Map comparison is order-insensitive by default but
one-to-one:
each candidate pair can satisfy at most one reference pair, including when an
adapter supplies malformed duplicate entries. Float
observations are compared exactly by default. Call
`compare_differential_runs(reference, candidate, DifferentialFloatTolerance{...})`
to opt into explicit absolute/relative float tolerance; negative tolerances remain
non-matching, and all non-float values stay exact. For a complete explicit policy,
call `compare_differential_runs_with_policy` with a
`DifferentialComparatorPolicy`: `DifferentialTextComparison.TrimFinalNewline`
removes one final LF (and its preceding CR) from text and process streams, while
`DifferentialMapComparison.Ordered` compares map pairs in source order. The
default policy is exact text, unordered maps, and zero float tolerance; policy
validation rejects unknown enum values and invalid tolerances. Version-3 ESDF
manifests persist these policy fields, so replay can validate comparison intent
without retaining the original in-memory case.

The owned comparison boundary has a closed value-kind admission check. Every
pending pair, including recursively reached array and map members, must use one
of the eight declared `DifferentialValueKind` cases; an unknown serialized enum
ordinal is a deterministic mismatch rather than an implicit text value. This
keeps future extensions from silently changing the meaning of malformed or
stale differential artifacts.

Runtime-to-owned conversion applies the corresponding public IR
`runtime_value_kind_valid` predicate at every recursive storage value before
matching it. A malformed nested `RuntimeValue` therefore raises the typed
`DifferentialRunnerError.Invalid` path instead of being interpreted as a scalar
or indexing aggregate fields under an unknown kind.
The interpreter/bytecode admission predicate independently scans the complete
caller-owned runtime pool before execution, so this adapter-level check is not
the only protection for nested snapshots.

The owned pool conversion also checks that every newly materialized aggregate
slice remains representable by its serialized `u32` offset domain before
truncating a host `usize`. Map placeholders are appended one pair at a time,
avoiding a host-side `count * 2` overflow on narrower targets; malformed or
unrepresentable snapshots raise `DifferentialRunnerError.Invalid`. The owned
pool itself is capped at one million values, and conversion raises
`DifferentialRunnerError.OutputLimit` before a direct or recursive aggregate
append would exceed that budget. Recursive conversion also rejects nesting past
128 aggregate levels, keeping malformed snapshots from exhausting the host call
stack; the depth guard is private to the module while the stable conversion
wrapper keeps adapter call sites typed and unchanged.

The comparator repeats the observation and owned-pool budgets before it creates
its explicit pending-pair or map-bijection state. Publicly assembled runs that
bypass adapter constructors therefore fail closed with a bounded comparison
record instead of allocating from an untrusted count.
Comparator work is bounded independently of pool size: it selects at most one
million pending pairs and rejects aggregate paths deeper than 128 levels.
Array pairs carry their depth through the explicit state machine, while map
pair matching propagates the same bound across its helper calls. Cyclic or
pathologically shared flat snapshots therefore become a deterministic
`ObservationValue` mismatch instead of an infinite comparison or host-stack
overflow.

The module keeps state-machine cursors, process-host symbols, and comparison
helpers private; only runner/value records and the documented adapter/comparator
entrypoints are public. Both runtime-to-owned conversion and comparison validate
array and map offsets with checked subtraction before indexing, so a wrapped
`u32` slice or an incomplete key/value pair cannot become a host access even
when a test supplies a malformed snapshot. Dedicated runtime and owned-map
fixtures cover out-of-bounds and maximum-offset cases.

The executable contract is `EsDifferential.DifferentialRunner`. It is a typed
specification, not a command-string escape hatch: the target executable, optional entry point,
working directory, environment overrides, stdin, protocol, timeout, dynamic
handlers, required effects, and required errors are separate fields, while process arguments remain
a `darray[sview]`. Call
`validate_differential_runner` before handing the value to an adapter. Its explicit
validation machine checks the name and target, requires an entry for adapter/module
runner kinds, rejects an entry on kinds that do not consume one, scans every argument
for embedded NUL bytes, requires a positive timeout, and requires a positive
`max_output_bytes` capture ceiling (64 MiB by default). A failed check returns
`DifferentialRunnerCheck` with a stable issue kind and argument index; it does not
launch anything.

The current runner kinds are `InProcessFunction`, `ElisascriptFile`, `ElisascriptProgram`, `NativeProcess`, `PythonAdapter`,
`CAbiFunction`, `WasmModule`, and `Service`. Adapters are responsible for turning a
validated specification into a `DifferentialRun`; keeping that execution layer
separate lets native, Python, and Elisascript adapters share the same deterministic
comparison and artifact machinery.

For `NativeProcess`, `target` is the executable and `arguments` are passed unchanged.
For `PythonAdapter`, `target` is the Python interpreter and `entry` names the adapter
script or module; the host adapter keeps that entry separate until it constructs the
argv vector. The validator rejects NUL bytes in executable-facing fields, including
the working directory, while stdin remains length-delimited so binary-compatible
fixtures are possible. Runner-level environment entries are ordered typed
`(name, value)` settings and never mutate the parent's environment. The
`environment_mode` field applies only to `DifferentialRunner.environment`; it
does not materialize or merge `DifferentialWorld.environment` into either side.
Case-world environment application remains the host adapter's open contract.
`environment_mode` defines how these entries relate to the child environment:
`Inherit` preserves the host environment and overlays the listed entries,
`Replace` passes exactly the listed entries, and `Clear` passes an empty
environment and rejects any entries. Exact modes use the provided `PATH` entry
for bare executable names; without one, use an executable path containing `/`.
Empty or relative `PATH` components retain POSIX meaning and are evaluated
after the requested working directory is selected.
The validator also caps the aggregate terminated C-string payload for the
executable, adapter entry, arguments, working directory, and environment at
64 MiB; each environment entry includes the `=` separator materialized by
`setenv`. Staged stdin is capped at 64 MiB. The low-level invocation boundary
repeats these byte checks before reserving or writing host buffers, so bypassing
runner preparation cannot turn a large differential case into an unbounded
allocation.
Length-only field admission runs before NUL scanning, so oversized borrowed
target, argument, working-directory, or environment views are rejected without
walking their bytes.
NUL scanning records a dedicated found flag rather than using a `length + 1`
sentinel, so a maximum-width text view cannot wrap while being validated.
Environment names are validated before launch: they must be nonempty, contain no
NUL byte, and contain no `=` separator; duplicate names are rejected as well.

Programmatic aggregate fixtures use `differential_array_value` and
`differential_map_value`. Both are typed fallible builders: they reject a
pre-existing pool offset outside the serialized `u32` domain, reject append
spans that would cross that domain, and reject odd map key/value input with
`DifferentialRunnerError.Invalid` before extending storage. Callers should
propagate that error rather than manufacturing a sentinel comparison value;
this keeps malformed fixtures from being mistaken for a parity mismatch.

For a native or adapter process, the materialization path should use the IR
`capture_process_result(executable(target), arguments, stdin)` intrinsic. The
explicit `executable` constructor gives a runtime target the same nominal type as an
`exe"..."` literal and rejects empty/NUL-containing names before launch. The capture
returns one
typed `ProcessCapture` snapshot, whose `process_exit_status`, `process_stdout`, and
`process_stderr` accessors populate the corresponding `DifferentialRun` fields. This
single execution is important for nondeterministic tools: separate stdout, stderr,
and status calls would observe three different runs. The intrinsic remains
shell-free and keeps process failures in `error[ProcessError]`.
The in-process adapter applies the same 64 MiB stdout/stderr ceiling before
materializing a `DifferentialRun`; an oversized borrowed snapshot becomes an
explicit `DifferentialRunOutcome.OutputLimit` instead of entering comparison.
Runtime-to-owned observation conversion applies the corresponding text/channel
ceilings as well, returning `DifferentialRunnerError.OutputLimit` before an
oversized text or borrowed `ProcessCapture` enters the differential value pool.
The adapter also bounds caller-supplied observation and value-pool snapshots at
that boundary, so oversized borrowed `ProcessCapture` fields cannot be carried
forward for a later comparison. It also rejects unknown value kinds and
out-of-range array/map views as a typed normal-error snapshot before
materialization.
The comparison entry point repeats that boundary for directly assembled runs
and value pools: each error/stdout/stderr channel and the aggregate text
envelope are checked before `differential_text_equal` or structured value
comparison can walk a borrowed view. Oversized input is rejected as a bounded
comparison error rather than being treated as a parity mismatch.

For Python-shaped adapters, the same snapshot can be read with typed fields:
`capture.returncode`/`capture.exit_status`/`capture.status`, `capture.stdout`, and
`capture.stderr` (the explicit `process_*` field spellings are also accepted).
These are aliases over the same one-shot accessors, so field syntax does not
change the differential run or introduce a second process invocation.

The standalone host boundary `execute_differential_process` consumes the same
`DifferentialProcessInvocation` produced by `prepare_differential_process`. It
constructs an argv vector directly (never a shell command), feeds stdin through
a temporary file, captures stdout and stderr independently, and applies the
selected environment mode in the child. `Inherit` overlays entries before
`execvp`; exact `Replace` and `Clear` modes pass a terminated environment vector
to `execve`, which does not perform the POSIX `ENOEXEC` shell fallback. The
`Inherit`/`execvp` path retains that platform fallback, so use an explicit
interpreter executable when a script requires one; no shell command string is
ever assembled. The argv terminator is cleared with `size_of(uintptr)` so the
slot is correct on both 32-bit and 64-bit targets. The timeout is a
bounded wait-poll budget; an expired child is killed and raises
`DifferentialRunnerError.Timeout`. A normal nonzero process status, including
the conventional `126`/`127` setup/exec statuses, remains ordinary
`DifferentialRun.exit_status` data for comparison. The typed
`DifferentialRun.outcome` additionally distinguishes completed execution from
normal error, spawn failure, crash, timeout, output-limit, and compile-failure
states; a signaled native child is classified as `Crash` before comparison.
Argument vectors are bounded
at one million entries before argv or owned C-string reservation, and environment
override entries use the same bound. The validator reports count and aggregate
byte limits as explicit resource issues; the low-level invocation API repeats
the check before launch.
`max_output_bytes` remains caller-configurable below the default 64 MiB ceiling,
but values above that hard capture budget are rejected before fork; this keeps
retained output materialization bounded even when a caller bypasses runner
preparation. Temporary-file sizes are sampled during wait polling and checked
again after exit; a fast child can overshoot between samples, but over-budget
bytes are rejected before either stream is allocated into the run result.
Runner and direct invocation timeout values must be positive and no greater than
the shared runtime step/poll ceiling. The poll counter checks this bounded budget
before incrementing, so it cannot wrap into an unbounded wait. Launch, wait, and capture
failures use `DifferentialRunnerError.Process`. stdout and stderr are checked
together against the runner's `max_output_bytes` ceiling before either stream
is allocated into the invocation result; exceeding the aggregate fails the
invocation instead of allowing captured output to exhaust the host. The combined
output size is checked during the wait loop and again after exit, so a
long-running child is terminated when its sampled aggregate crosses the
ceiling. Each child creates a private process group before `execvp`; timeout and output-limit
cleanup signal that confirmed group and then reap the leader, preventing
descendants from surviving a failed differential case. Cleanup first sends
cooperative `TERM`, waits through a bounded no-hang grace window, and then
escalates to group `KILL` before returning—even when the leader was already
reaped during the grace window. If parent-side `setpgid`
is interrupted it is retried through a bounded `EINTR` budget; POSIX `EACCES`
after child-side group setup is treated as confirmed admission, while any
other non-retryable failure causes the adapter to terminate/reap the direct
leader, close all temporary streams,
and returns `DifferentialRunnerError.Process` before continuing. It never runs
with a direct-PID-only cleanup policy that could leak descendants. Group setup is
therefore fail-closed on POSIX; adapters on platforms without process groups
must report that limitation before launching a case. The
child's stdin/stdout/stderr `dup2` setup uses the same bounded retry before
returning the typed process failure. Child-side process-group admission also
retries `EINTR` and exits before `execvp` if isolation cannot be established. The
post-exit reader owns both temporary streams as a pair: if either stream fails
or exceeds the ceiling, the sibling is closed before the typed failure is
propagated, preventing descriptor leaks across repeated negative cases. Any
parent-side `waitpid` or stream-position failure after `fork` also terminates
the confirmed private group (or only the direct leader when group setup failed)
and reaps it before returning `Process`, so capture errors cannot strand a
running child or zombie. The termination signal and blocking reap each retry
bounded `EINTR` interruptions before giving up, preserving this cleanup
guarantee when the parent is itself interrupted during failure handling.
An interrupted non-blocking `waitpid` is retried through the bounded polling
state machine before the child is classified as a process failure; a successful
poll resets that retry budget. The one-millisecond polling sleep also retries
bounded `EINTR` interruptions and becomes `Process` only after the retry budget
or host sleep contract is exhausted.
Stdin staging also retries short temporary-file writes until the bounded payload
is complete or a zero-progress failure is observed. Each host-returned write count
must also fit the requested remaining span; impossible over-counts fail as
`DifferentialRunnerError.Process` before the offset is advanced.
Post-exit stdout/stderr materialization applies the same bounded progress policy
to exact-size reads: positive short `fread` counts advance and retry, while zero
progress or an over-count fails the owned stream snapshot as
`DifferentialRunnerError.Process`.
The same reader rejects a positive count accompanied by the host `ferror`
indicator, so a sticky temporary-file error cannot be classified as a complete
stdout/stderr snapshot.
Temporary stdin writes use the same admission for positive short `fwrite`
progress and reject a host `ferror` indicator before advancing the owned offset,
so a poisoned input stream cannot be presented to the reference or candidate as
complete input.
Post-exit file sizes are also round-tripped through host `usize` before
allocation; a stream size representable in `i64` but not on the target host is
reported as `DifferentialRunnerError.Process` rather than truncated.

When a differential case needs both hermetic filesystem context and temporary
environment values, use
`capture_process_result_in_directory_with_environment(executable, arguments, stdin,
directory, environment)`. It changes directory and applies each `dict[sview, sview]`
override only after `fork`, so neither control leaks into the runner process. The
single `ProcessCapture` snapshot keeps status, stdout, and stderr aligned to the
same child invocation.

`run_differential_process` is the convenience entry point for this complete
path: it validates and prepares a `DifferentialRunner`, then executes the
resulting invocation in one typed call. Hosts that need to inspect the exact
argv/cwd/timeout before launch can keep using the two lower-level operations.

`run_differential_elisascript` is the in-process counterpart for a candidate
`.elisascript` file. Set `kind` to `ElisascriptFile`, `target` to the source path,
`entry` to the function to invoke, keep arguments as a text vector, and provide
verified host-configured handlers through `handlers` when the candidate uses
dynamic effects that need captures, introduced effects, or explicit error rows.
Simple operation callbacks can instead use the source-level
`@handler("name", "Family.Operation"[, "Policy"])` decorator; those clauses are
derived during lowering and are available to the same in-process runner. The helper
uses the canonical source/file execution boundary, converts the typed return value
and `observe` events into owned differential values, and propagates source and
runtime error families unchanged. Its `timeout_steps` field is the VM step limit;
filesystem and process effects therefore remain visible through the same typed
capabilities as ordinary script execution. Its `max_output_bytes` setting is
passed through the policy-aware bytecode facade to the runtime output budget;
lower-than-default output ceilings use the interpreter path until direct
bytecode supports custom output limits. Both engines reject an oversized
standard-stream write before emission. Process captures in the reference path
are charged against the remaining combined output budget before allocation;
the direct engine currently rejects an over-budget combined capture after its
capture instruction returns, as called out above.
The in-process adapter rejects a nonempty `working_directory`, `environment`,
text or binary stdin payload, or `protocol`, as well as any non-`Inherit`
`environment_mode` or enabled binary-stdin mode, with
`DifferentialRunnerError.UnsupportedConfiguration`; use a process runner when
a candidate must execute in a separate configured world.
Source targets also respect the source loader's 4 KiB filename ceiling and are
rejected before terminated-buffer allocation when they reach that bound.

For a runnable script that follows the launcher ABI, use `ElisascriptProgram` and
omit `entry`; its `handlers` field has the same meaning. `run_differential_elisascript_program` invokes
`main(arguments: darray[sview]) -> i64`, preserves each argument as typed text,
and records the returned signed integer in both `return_value` and
`exit_status`. This makes the in-process candidate directly comparable with a
native reference process whose exit status carries the same program result.

`differential_run_from_process_capture` is the typed adapter for that boundary. It
accepts the interpreter's `EsIr::RuntimeValue` snapshot plus structured observations
and materializes one `DifferentialRun`; an optional `DifferentialRun.values` pool
keeps any array observation indices attached to the same run. A non-`ProcessCapture`
value becomes a stable adapter error. Process adapters mirror their exit status in
the typed `return_value` field as an `Int`, which lets a standard Elisascript
program and a native executable be compared under the same return/exit contract.
Its validation/materialization path is an explicit state machine, so the process
result cannot be partially copied.

## Runner types

First-class runners should cover:

- An Elisascript or Elisa function in the same process
- A native executable using stdin/stdout or files
- A long-lived subprocess using a framed protocol
- A C ABI function loaded from a library
- A Python module/function through an explicit adapter process
- A WebAssembly module
- A VM, emulator, or service reached through a custom handler

```elisa
enum Runner[I, O]:
    Function(run: fn(I) -> O)
    Process(command: Command, protocol: ProcessProtocol[I, O])
    DynamicLibrary(library: Path[File, Existing], symbol: SymbolName)
    Wasm(module: Path[File, Existing], export: ExportName)
```

Adapters must make serialization, timeouts, exit behavior, and required effects
explicit in their types.

## Observations

Comparison should operate on typed observations rather than incidental output:

```elisa
struct CpuObservation:
    registers: Registers
    flags: Flags
    memory_writes: darray[MemoryWrite]
    io_events: darray[IoEvent]
    cycles: u64
```

Standard observation sources should include:

- Return value or error variant
- Exit status
- stdout and stderr
- Filesystem changes
- Structured trace events
- Memory/register snapshots
- Network requests made through a recording handler
- Effect traces
- Performance counters when explicitly requested

## Comparison policies

```elisa
Comparator.exact[State]()
Comparator.float(tolerance = FloatTolerance{absolute: 1e-9, relative: 1e-6})
Comparator.unordered[Event]()
Comparator.text(normalize = [Normalize.line_endings, Normalize.paths])
Comparator.fields[State](ignore = [.timestamp, .host_address])
```

Normalization must be explicit and reported. The framework must never silently
discard nondeterministic fields merely to make a test pass.

Float comparison is exact by default. Explicit absolute and relative tolerances
must be finite and nonnegative; case validation rejects NaN and infinity before
launch. NaN never equals anything, equal infinities compare equal, and an
infinity cannot match a finite value through relative scaling.

The implemented policy surface is intentionally narrower than the eventual
normalization catalog: path rewriting, timestamp normalization, ignored fields,
unordered arrays, and flaky/nondeterminism policies remain future explicit
extensions rather than implicit transformations.

## Deterministic worlds

Both sides should receive the same controlled world where possible:

```elisa
with Clock = FixedClock(seed.time):
    with Random = SeededRandom(seed.random):
        with Environment = TestEnvironment(seed.environment):
            with FileSystem = SnapshotFileSystem(seed.files):
                Differential.run(case, input)
```

External reference executables cannot always share in-process handlers. Their
runner should materialize the same environment, working directory, fixture tree,
arguments, stdin, resource limits, and random seed before launch.

Fixture file names are relative to the materialized world root. Case validation
rejects absolute names, empty path components, `.` and `..` components, NULs,
backslashes (fixture paths use `/` as their only separator), and duplicate paths
before any filesystem operation. It also rejects a fixture file used as an
ancestor of another fixture or as the world working directory.
`DifferentialWorld.working_directory` is likewise empty (meaning the root) or a
canonical relative path beneath that root; absolute paths, traversal
components, and backslashes are rejected. The
adapter must create and bind that directory inside the isolated root rather
than treating caller input as permission to escape the fixture tree. This
world-level path is distinct from each runner's working-directory setting;
current case preparation still does not merge either world setting into a
runner invocation.

## Reproducible failures

Every mismatch produces a self-contained artifact directory:

```text
artifacts/differential/z80-step/2026-08-28T.../
  case.elisadiff
  input.bin
  input.json
  reference.json
  candidate.json
  comparison.json
  reference.stdout
  reference.stderr
  candidate.stdout
  candidate.stderr
  effects.jsonl
  reproduce.elisascript
```

The report records executable hashes, compiler versions, arguments, environment,
platform, timeout, normalization rules, random seed, and source revision. A single
command must reproduce the failure:

```text
es diff reproduce artifacts/differential/z80-step/.../case.elisadiff
```

When either side is an Elisascript module, the artifact also records its verified
IR `canonical_module_bytes`, `module_fingerprint`, and canonical SHA-256 digest.
The bytes are a field-wise, order-sensitive encoding, the `u64` fingerprint is
their compact stable correlation key across the interpreter, bytecode, JIT,
native, and Wasm lowerings, and the digest is the cryptographic identity used
for cache/artifact binding. A report can therefore prove that all engines ran
the same typed module without depending on host pointers or backend instruction
numbering. The canonical bytes, verified module, digest, and source revision
remain part of the reproducible artifact.
Persisted metadata should use `canonical_bytecode_artifact_bytes`, the
version-2 length-prefixed `ESBC` envelope, which carries the four fixed-width
digest words and rejects legacy version-1 records until they are migrated. Its
`bytecode_artifact_fingerprint` is a deterministic cache/correlation key only;
the artifact still must satisfy `bytecode_artifact_matches_module` against the
exact verified module and capability report before execution.
`canonical_differential_artifact_manifest_bytes` emits ESDF version 5 and binds
the canonical observation schema with four SHA-256 words; a complete verified
module digest remains available as a separate four-word binding. Versions 1–4
remain decodable for compatibility but are explicitly unbound from the schema.
Version 5 carries an explicit module-digest presence bit and always includes all
four schema-digest words; inconsistent presence metadata and truncated fields
are rejected before a replay bundle is opened.
`differential_artifact_manifest_requires_migration` reports when a valid legacy
manifest needs an explicit schema-upgrade step; malformed bytes remain invalid
rather than being mislabeled as migratable.
Use `make_differential_artifact_manifest_for_module` when the verified module is
in hand; it derives both the compact fingerprint and all digest words in one
typed constructor so callers cannot accidentally omit the cryptographic bind.
It fails with `DifferentialRunnerError.Invalid` if canonical digest production
returns an unavailable/oversized sentinel rather than producing a partial bind.
All ESDF, ESPS, ESRP, ESVP, and ESCR borrowed text fields now use the shared
`runtime_bounded_slice_end` subtraction guard; fixed-width lookahead admission
also checks remaining bytes before indexing, so malformed sidecars fail before
pointer construction.
The bytecode adapter must additionally record `BytecodeCapabilityReport` before
execution and the returned `Execution.engine` afterward. The report includes the
direct/fallback decision and function, instruction, and global counts. A case that
claims independent interpreter/VM evidence fails if the candidate reports
`BytecodeInterpreterFallback`, even when the values happen to match. In-process
`DifferentialRun` values expose this as `engine_known` plus `engine`; external
process runs leave `engine_known` false because their implementation engine is
outside the Elisascript runtime.

The comparison layer emits a bounded version-2 `ESCR` comparison-report sidecar.
`make_differential_comparison_artifact` binds the report to the manifest
fingerprint and records the first difference kind/index, both backend identities,
run outcomes, top-level value kinds, and length-delimited reason/stdout/stderr/error text.
`canonical_differential_comparison_artifact_bytes` and
`decode_differential_comparison_artifact` enforce the one-megabyte envelope,
checked lengths, explicit membership for every serialized enum byte, and
trailing-byte rejection. Its compact fingerprint is a correlation key, not a
cryptographic digest; aggregate value pools and complete process streams remain
separate artifact payloads. The same raw-byte predicates are shared by the
manifest's engine/artifact/comparator policies and by the process, value-pool,
and index sidecars, so reserved or non-contiguous future ordinals fail closed
before they can default to the first constructor. Fixed-width readers validate
the cursor bound before subtracting each byte window, keeping truncated or
malformed sidecars fail-closed before any indexed read.

`EsDifferentialReport::DifferentialReport` is the renderer-neutral report
boundary. It accepts Human, JSON, or JUnit format requests but keeps status and
failure category typed: a pass must use `None` and be deterministic, a failure
must identify a concrete mismatch/process/timeout/crash/artifact category, and
an inconclusive result is limited to flaky or infrastructure causes. Case and
engine identities, bounded summaries/messages, repeat counts, and optional
artifact paths are length/NUL checked before a renderer emits text. Renderers
must preserve these fields rather than reclassify failures from free-form
stdout or exit codes.

Each side's complete bounded process-facing payload can be persisted separately
as an `ESPS` process-stream artifact with `make_differential_process_stream_artifact`.
It binds the reference/candidate side, terminal outcome, signed exit status, and
length-delimited error/stdout/stderr channels to the manifest fingerprint. The
versioned encoder and borrowed decoder reject unknown side/outcome ordinals
through explicit raw-byte membership checks,
oversized channels, truncation, and trailing bytes; the compact fingerprint is a
correlation key and not a cryptographic digest. Aggregate typed value pools remain
a separate payload contract so large arrays/maps do not inflate either sidecar.

The reproduction entry point is a separate `ESRP` sidecar. Its typed target and
entry fields are length-delimited and bound to the same manifest fingerprint;
they identify an Elisascript launcher target without storing an opaque shell
command. Empty, NUL-containing, oversized, unknown-version, truncated, or
trailing-byte payloads are rejected before a replay adapter can use them.

Typed aggregate results are persisted in a bounded `ESVP` value-pool sidecar.
It records the run side, outcome/status, root value, flat array/map storage, and
observation traces. Every value record carries its kind, checked u32 spans,
length-delimited text/process fields, and the exact IEEE-754 bit pattern for
floating-point values. The decoder allocates only after bounded count admission,
then rejects malformed kinds/spans, truncated records, and trailing bytes. Raw
kind bytes use explicit membership admission rather than only a maximum ordinal,
so reserved or non-contiguous future kinds fail closed instead of becoming
`Void`.

An `ESIX` artifact index binds the manifest, comparison report, both process
streams, reproduction entry, and both value pools by fingerprint. Its explicit
`Prepared` and `Complete` publication states let an atomic writer stage a bundle
without exposing a partial directory; `Complete` is rejected unless every
required sidecar fingerprint is nonzero. The index itself is bounded,
length-free, versioned, and rejects unknown publication bytes or trailing bytes
through an explicit state-membership predicate.
Before a replay adapter opens or launches anything, `validate_differential_artifact_bundle`
runs a state-machine admission check over the complete in-memory bundle. It
requires a valid `Complete` index, recomputes the manifest fingerprint, checks
each sidecar's validity and manifest binding, enforces reference/candidate side
identity for process streams and value pools, and compares all six recorded
sidecar fingerprints. Prepared, stale, mixed-side, malformed, or cross-manifest
bundles return a typed `DifferentialArtifactReplayCheck` failure and are not
eligible for replay; the validator itself never executes the reproduction entry.

`DifferentialWorldSnapshot` captures the complete validated world contract and
its deterministic fingerprint. `validate_differential_world_snapshot` checks
the current world, the stored snapshot, and the post-run fingerprint in a fixed
state-machine order, so changes to fixture bytes/metadata, cwd, environment,
argv, stdin, locale, timezone, or seed become a typed contamination failure
before comparison. This is the identity boundary for host materializers; it
does not itself capture or restore a post-run filesystem tree.

`DifferentialWorldMaterializationPlan` makes that host boundary explicit for
two separate absolute roots. Its lifecycle is `Planned → Materializing →
Materialized → Running → Restoring → Restored`, with partial materialization,
materialized-world, and running states all permitted to enter `Restoring` for
cleanup. Roots must be distinct, bounded, NUL-free, and free of empty, dot, or
parent components. The validator binds both roots to a valid world snapshot,
and the transition helper authorizes exactly one nonterminal edge without
performing I/O. An adapter must enter `Materializing` before it starts host
mutations. Only `complete_differential_world_restoration` may mark the plan
`Restored`; it validates both isolated restored worlds against the original
snapshot fingerprint first, leaving a rejected restore in `Restoring`. A future
adapter must perform fixture creation, cwd/environment setup, cleanup, and
restoration around these states. The plan is a public value record, so its
validator establishes structural consistency, not tamper-proof provenance; a
host adapter must keep ownership of the live plan and must not trust a
caller-constructed terminal record as proof that filesystem cleanup occurred.
The Darwin runtime bridge exposes `open`, `openat`, `readlinkat`, `fdopendir`,
`fstatat`, `fstat`, `fchdir`, and the no-follow stat flag. The first
source-only host slice, `EsDifferentialWorldPosix`, consumes the descriptor-
relative primitives to create a unique 0700 temporary root, retain parent/root
descriptors, and materialize one already-validated snapshot's inferred cwd
directories and regular text/byte fixtures. Each path component is opened
individually with `O_NOFOLLOW`; fixture files are created no broader than 0600,
written with bounded short-write/EINTR handling, then assigned and checked
against the requested exact mode and byte length. The directory/stat ABI and
this adapter are Darwin-arm64-specific.

Cleanup is now available through cleanup_darwin_differential_world, but this
is still not a replay-ready host adapter: it has no recursive post-run world
snapshot/readback, world argv/environment/stdin/locale/timezone/seed merge,
paired-root orchestration, or process launch. Materialization preflights a
conservative count of fixture and inferred-directory entries plus a maximum
directory depth so an admitted initial world fits the cleaner's fixed limits
(1,048,576 entries and 1,024 nested directories). A child can exceed those
limits; cleanup then stops with a typed error and may be retried after the tree
is brought back within bounds. The operating system's open-descriptor limit
can also stop a deep traversal before the configured depth ceiling; this is a
typed host-I/O failure, not a reason to retry while the same resource pressure
persists. The traversal is iterative, checks device and directory identity,
treats symlinks as unlink-only leaves, and recovers
runner-restricted directory permissions with descriptor-relative
fchmodat(..., AT_SYMLINK_NOFOLLOW) before opening them. It requires the child
and every other writer to be stopped; it is not safe against a concurrent
hostile mutator. Partial failures can leave a partially cleared temporary tree
and retained descriptors, and Elisa does not enforce the root record's
single-owner descriptor contract. A successful unlink interrupted before its
outcome is recorded is resolved from the held parent descriptor on retry;
descriptor-close outcomes that remain ambiguous fail closed rather than
reusing a possibly stale descriptor number.
It is not a sandbox; a launched process would still be able to access host
paths outside the root. `fdopendir` takes ownership of its descriptor on
success; a retained root must be enumerated through a separate descriptor.
`fchdir` mutates process-global state and belongs only in a forked child.
`fstat(fd, ...)` verifies metadata on the opened object itself;
`fstatat(..., SYMLINK_NOFOLLOW)` observes an entry without following its final
component, but callers must still walk one validated path component at a time.
`readlinkat` returns raw target bytes without a NUL terminator; a return equal to
the supplied buffer capacity is potentially truncated and requires a bounded
retry or explicit rejection.

`EsDifferentialFilesystem::DifferentialFilesystemSnapshot` is the post-run file
tree boundary. Adapters may submit relative file, directory, and symlink entries
in strict byte order, or collect an unordered batch and seal it with the
bounded in-place O(n log n) heapsort. Both paths enforce 4 KiB per path, a
64 MiB aggregate path-byte budget, a 256 MiB content-byte budget, the entry
count ceiling, and typed metadata. Appends account only for the new entry; the
complete record list is revalidated at seal rather than rescanned on each
append. The unordered path detects duplicate names after sorting; because that sort has
mutated the batch, a duplicate transitions the snapshot to `Failed` before
returning `EntryOrderInvalid`. A snapshot must be sealed before comparison, and
`compare_differential_filesystem_snapshots` merges the ordered streams to report
the first missing path, kind, content, size, mode, or executable-bit difference.
The compact snapshot fingerprint is stable for the sealed ordered record. This
contract performs no filesystem I/O. Entry paths are still borrowed `sview`s,
so a host collector must retain their backing storage for the complete snapshot
lifetime; the logical path-byte budget does not itself provide ownership.
During collection, callers must append through the snapshot APIs rather than
editing the public entry array or accounting fields directly. Sealing rechecks
all entries and counters before publication, but direct field edits are detected
there rather than on every append.
Host materializers remain responsible for collecting entries and preserving the
world lifecycle.

`EsDifferentialOrder::DifferentialOrderSession` makes order-contamination checks
explicit. A bounded session records at most one `ReferenceThenCandidate` and one
`CandidateThenReference` observation, including the initial and final world
fingerprints and the comparison fingerprint. Completion requires both orders by
default. A changed final world is `WorldContaminated`; a changed comparison is
`OrderDependent`; stable fingerprints in both orders are `OrderIndependent`.
Contamination and order-dependency flags are derived cumulatively from every
retained observation, so a later clean ordering cannot erase an earlier world
leak. The policy either rejects contamination before completion or reports the typed
classification for an inconclusive artifact. The contract does not execute or
restore a world; adapters must perform those operations around each run.

`EsDifferentialTraceWindow::DifferentialTraceWindow` bounds the context retained
around a lockstep divergence. Its policy fixes the number of steps before and
after the anchor and a total event ceiling; records must be strictly ordered,
inside that range, and carry nonzero reference/candidate fingerprints. The
anchor record is required before sealing and must contain a non-equal pair, and
each record is classified as `Before`, `Divergence`, or `After`. A sealed
window has a deterministic compact fingerprint suitable for an artifact
sidecar, while full trace collection stays with the adapter.

`EsDifferentialEffectTrace::DifferentialEffectTrace` preserves the observable
part of algebraic-effect behavior for parity cases. Each ordered event carries
the effect family and operation identity, payload/result fingerprints, and an
explicit resumption count plus multishot marker. Event count, operation text,
fingerprints, resumption count, and contiguous sequence indices are bounded
before sealing. The comparator reports the first family, operation, payload,
result, or resumption difference; malformed records produce an explicit
`Invalid` comparison, including forged sequence indices, and an effect trace is
never treated as equal merely because the final return value matches.

`EsDifferentialReplay::DifferentialReplaySession` is the lifecycle seam between
validated artifacts and a future host replay adapter. Admission binds the
manifest identity, materialization binds the world fingerprint, and the policy
selects reference-first or candidate-first execution. Each later phase retains
all of its prerequisites: both ordered run fingerprints and exactly two runs are
required before comparison, and restoration must return the expected world
fingerprint before the session can complete. Materialization attempts are
recorded before host work begins, so failure or cancellation after that point
enters `Restoring` even if `WorldReady` was never acknowledged. A failed or
cancelled session is terminal only after the original world fingerprint is
verified; pre-materialization termination remains safe to complete directly.
Conflicting termination requests, rejected order, stale admission, wrong-world,
missing-comparison, forged phase flags, and failed-restore edges remain typed
state errors. The contract does not launch the reproduction entry or perform
cleanup itself.

`DifferentialCaseReplaySession` composes that lifecycle with a validated
`DifferentialCase`, its exact ESDF v5 manifest, the world snapshot, and the two-
root materialization plan. The adapter admits the case, records materialization
before host mutation, acknowledges both ready roots, obtains sides only in the
declared order, and submits typed completed runs. The coordinator computes run
identities from bounded process/value-pool artifacts and all capability and
resource metadata, and binds the session to both runner configurations, case
limits, and owned root-byte snapshots. Adapters can obtain borrowed views of
those stable roots for host I/O instead of retaining caller-provided path
views. It routes the paired comparison through
`compare_differential_case_runs`, including the observation schema. Success,
failure, and cancellation after materialization enter cleanup; mismatched
composite state is rejected before termination changes either lifecycle.
Retained run evidence is re-fingerprinted on validation, so post-comparison
mutation prevents artifact access. A rejected restore remains retryable.
Comparison-artifact access is withheld until both restored-world declarations
match the snapshot and the replay reaches `Completed`. These APIs coordinate
and validate adapter claims; they do not create directories, launch processes,
or prove host I/O provenance.

`EsDifferentialRedaction::DifferentialRedactionPolicy` is the explicit secret
boundary for environment metadata captured into artifacts. Policies select exact
names or redact all values; captured entries retain the name and a deterministic
value fingerprint while storing an empty value for redacted fields. Duplicate
names, embedded NULs, oversized text, aggregate text-count mismatches, and
malformed redacted entries fail before sealing. This keeps replay identity
checkable without persisting credentials;
adapters still decide which environment fields are necessary to capture.
Redaction admission proves the remaining text budget is at least the separator
width before subtracting it, so a tiny remaining budget cannot wrap the value
capacity check.

`EsDifferentialGenerator::DifferentialGeneratorSession` is the deterministic
input-generation boundary. It records one base seed, derives each case seed
from its ordinal, requires ordered fingerprints, and bounds both case count and
aggregate generated bytes. Validation derives the aggregate byte count from
retained payload sizes, so a forged total cannot under-report generated data. A
caller cannot supply an ambient or out-of-order seed, and completion requires at
least one generated case. The generator only
admits typed seed/fingerprint metadata; actual schema-aware input construction
and shrinking remain adapter responsibilities.

The directory publication protocol is modeled separately from the host I/O
adapter by `DifferentialArtifactDirectoryPlan`. A plan has a bounded parent
path and two single-component names: a private staging directory and a distinct
published directory. Component names reject empty, dot, parent, slash,
backslash, and NUL forms. Its state machine is `Staging`, `Ready`, then
`Published`; staging accepts only a `Prepared` ESIX index, while the latter two
states require `Complete`. The eventual POSIX adapter must create and populate
the staging directory, write the complete index last, and rename the directory
within the same parent without shell evaluation. `advance_differential_artifact_directory`
allows only the single forward edges `Staging → Ready` and `Ready → Published`
and never mutates the plan on a rejected transition. The plan validator covers
the ordering and path contract now; actual directory creation, fsync policy, and
crash-recovery testing remain execution work.

`shrink_differential_case` provides the first bounded reduction layer for
counterexamples. It walks world files, binary payloads, argv entries, environment
entries, and text or binary stdin in a fixed order, removes or clears one item per candidate,
revalidates the complete case, and stops at the caller's budget (capped by a
runtime default). Candidates carry a typed reduction kind and borrow the original
runner/text payloads; an invalid source case yields no candidates and the source
case is never mutated. Clearing a binary payload preserves its explicit byte-file
kind, so the reducer never silently turns binary data into text.
`shrink_differential_runs` adds the next bounded layer for already captured
runs: it clears each side's stdout/stderr and removes each observation in a
fixed order, retaining only candidates whose original first-difference kind
survives. It never mutates the input pools or launches either side, and caps
candidate count at the same runtime default. It then clears one aggregate
array/map slot at a time from each side's owned value pool, after validating
every root, observation, and nested range; the original mismatch category must
still survive, so an aggregate reduction cannot silently turn a value mismatch
into a pass or a malformed-pool result. Process termination/timeout shrinking
and replaying candidates against the original world remain separate follow-up
layers. `DifferentialShrinkTrace`
records each retained candidate fingerprint and reduction kind, requires the
original mismatch category to survive, and only permits completion when the
adapter explicitly records that its candidate budget is exhausted. Validation
also rejects a minimality proof on any non-complete trace. This keeps “minimal”
as an evidence-bearing claim instead of an inference from an empty candidate
list.

`EsDifferentialTimeout::DifferentialTimeoutSession` records the timeout-shrink
layer separately from process control. A host adapter proposes a strictly
smaller reference or candidate poll budget, reruns the unchanged world, and
submits a nonzero comparison fingerprint only when the original mismatch kind
survives. Candidates are accepted in ordinal order under a bounded budget;
validation replays retained candidate ordinals, mismatch kinds, fingerprints,
and strictly decreasing budgets, reconciles the current budget with the last
accepted candidate, and keeps pending metadata bounded. Completion requires an
explicit exhausted marker, and no event in this contract launches, signals, or
kills a process.

Independent references use `DifferentialOracle`, which pairs a closed source
language identity with a validated external runner. Python requires the typed
`PythonAdapter`; Perl, AWK, and shell references use the shell-free
`NativeProcess` argv boundary; C/C++ may use a native process or `CAbiFunction`;
and generic native references may use a native process, ABI function, Wasm
module, or service. Elisascript and in-process runners are rejected as oracles,
and invalid names, versions, language ordinals, runner contracts, or language/
adapter combinations fail before any adapter launch.

The execution boundary now carries a backend-neutral `ExecutionCapability`
snapshot alongside that engine identity. For bytecode runs,
`capability_known` is true and the snapshot preserves `direct_supported`,
`function_count`, `instruction_count`, and `global_count` from the preflight
report. Differential adapters copy those fields into `DifferentialRun` so a
serialized or later comparison record cannot lose the pre-run capability facts.
Reference-interpreter and external-process runs deliberately leave the snapshot
unknown; zero counts must not be interpreted as proof that a module was empty.

In-process runs also copy the shared `RuntimeResourcePolicy` and
`RuntimeResourceUsage` into `DifferentialRun`. External oracle processes leave
`resource_policy_known` false because the adapter cannot observe their memory,
handle, process, regex, or concurrency counters. This keeps resource metadata
available for later artifact publication without pretending that a process
boundary has been measured. Direct-bytecode nested calls carry their parent's
output ledger through the call chain, so the copied usage snapshot includes
completed child captures exactly once, even when a child fails after a partial
capture and the parent resumes through an error guard.

`compare_differential_resource_usage` is the explicit resource-parity gate for
known in-process runs. It rejects unknown snapshots as `Unknown`, requires the
same bounded policy, and then compares steps, elapsed time, memory, open handles,
processes, output, regex work, retained traces, and concurrent tasks in a fixed
order. An open-handle/process/task difference therefore remains a typed cleanup
failure instead of disappearing behind equal stdout or return values. External
processes remain eligible for ordinary behavioral comparison, but cannot claim
resource equivalence without an adapter-owned snapshot.

`compare_differential_runs` remains a value/observation comparator and therefore
does not reject an unknown engine by default. Backend qualification must use
`compare_differential_runs_with_engine_requirement` with an explicit
`DifferentialEngineRequirement`: `RequireKnown` checks that both sides report an
engine, `RequireDistinct` additionally requires different known engines, and
`RequireDirectBytecodeCandidate` requires the candidate to have run the direct
bytecode engine. A failed requirement returns the machine-readable `Engine`
difference kind with both recorded engine identities, before ordinary output or
return-value comparisons. This prevents a compatibility fallback from being
mistaken for independent VM evidence while retaining flexible comparisons for
external legacy references.
For any non-`Ignore` requirement, the same gate rejects contradictory metadata:
capability snapshots require a known engine, direct-bytecode identity requires
`direct_supported`, and fallback identity requires it to be false. The default
value comparator continues to ignore engine metadata so external references can
remain unqualified compatibility inputs.

`EsDifferentialSequence::DifferentialSequence` is the bounded stateful/lockstep
boundary. Each step has an ordered index, independent reference/candidate
fingerprints, an observation count, and an explicit equality decision. The
sequence validator reconciles the aggregate observation count against the
per-step counts before accepting a trace;
`EsDifferentialStability::DifferentialStabilitySession` is the bounded repeat
boundary for adapters whose output may vary between runs. A policy declares a
minimum and maximum repeat count (capped at sixteen) and explicitly chooses
whether nondeterminism is rejected or reported. Every repeat records reference,
candidate, and comparison fingerprints plus the equality decision. Repeated
tuples classify as `StableEqual` or `StableMismatch`; any changed tuple is
classified as `Nondeterministic` and can never be converted into an equality
result. Validation derives the stable-repeat count and nondeterminism flag from
the retained observations and rejects forged baseline or aggregate accounting.
The state machine requires the minimum repeat count before completion, rejects
out-of-order or missing fingerprints, and leaves execution, scheduler seeds,
and host adapters outside the typed contract.
checkpoints carry both state identities. The state machine records the first
non-equal step as `Diverged`, seals only after every step is complete, and
rejects out-of-order steps, duplicate checkpoint order, zero identities, and
observation growth beyond the shared ceiling before an adapter can retain a
trace.

## Generation and shrinking

Differential cases should integrate property-based generation and deterministic
shrinking:

```elisa
inputs: Generator[CpuInput] = generate:
    opcode <- Gen.u8()
    registers <- Registers.generate()
    memory <- Gen.bytes(length = 65536)
    return CpuInput{opcode, registers, memory}

shrink input:
    yield input with .memory = []
    yield input with .registers = Registers.zeroed()
    yield from input.memory.shrink()
```

Shrinking reruns both implementations and retains only candidates that preserve the
mismatch. The complete shrink path is recorded.

## Stateful and lockstep testing

Ports of emulators, parsers, compilers, and protocol engines need more than
input/output comparison. Elisascript should support stepwise lockstep:

```elisa
Differential.lockstep(reference, candidate, program) |step|:
    compare(step.reference.state, step.candidate.state)
    compare(step.reference.events, step.candidate.events)
```

On divergence, it should identify the first differing step and retain surrounding
trace context. Optional checkpoints permit binary search over long executions.

## Compiler backend differential tests

The same framework will test Elisascript itself:

```text
same typed program
  ├─ bytecode VM
  ├─ LLVM JIT
  ├─ LLVM AOT
  └─ WebAssembly
```

The compared observation includes return values, errors, output, effect traces,
resource cleanup, and generated files. Backend parity therefore uses the same public
framework as user port-validation projects.

## Planned library layout

```text
src/testing/differential.elisa   # initial typed run/observation comparator
stdlib/testing/differential/
  case.elisa
  runner.elisa
  protocol.elisa
  observation.elisa
  comparator.elisa
  normalize.elisa
  generator.elisa
  shrink.elisa
  lockstep.elisa
  artifact.elisa
  report.elisa
```

The VM and effect runtime must preserve deterministic effect traces and source spans
because differential testing depends on them. This requirement therefore influences
MIR, bytecode, handlers, subprocess APIs, and artifact formats from the beginning.
