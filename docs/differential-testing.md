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
working directory, fixture files, ordered environment, argv, stdin, locale,
timezone, and seed. `validate_differential_case` validates both nested runners,
rejects NULs, duplicate fixture paths, oversized world data, invalid engine or
artifact policies, and preserves the nested runner issue kind. A validated case
can produce a `DifferentialArtifactManifest` with case/runner identities, seeds,
engine requirement, artifact policy, and optional verified-module fingerprint;
adapters remain responsible for materializing the separate worlds and writing
the complete output artifact.

The first shared comparison primitive is `EsDifferential.compare_differential_runs`.
It compares exit status, named error, stdout, stderr, the typed return value,
observation count, and then each `(trace, value)` pair in that fixed order. It returns a typed
`DifferentialComparison` describing the first difference, including the relevant
text or values; identical runs return `DifferentialDifferenceKind.Equal`. The
comparator is implemented as an explicit Elisa state machine, so it cannot skip a
comparison phase or silently continue after a mismatch.

The interpreter and direct-bytecode engine cap ordered `observe` events at one
million per run. Crossing that shared budget raises `InterpretError.OutputLimit`
before the next event is appended; differential adapters therefore receive a
bounded trace rather than an implicit unbounded memory commitment. The runtime
adapter also rejects externally supplied observation snapshots above the same
budget before converting any element into its owned comparison pools.

Observation and return values include `Void`, `Bool`, `Int`, exact `Float`, `Text`, recursive
`Array`, order-insensitive `Map`, and structured `ProcessCapture` kinds. Arrays
use a flat, owned value pool (`DifferentialRun.values`) with `(array_start,
array_count)` slices; maps use interleaved `(key, value)` pairs with
`(map_start, map_count)`, so nested observations remain deterministic without
borrowing an interpreter's runtime storage. `append_differential_observations_from_runtime`
performs that conversion and rejects out-of-bounds snapshots through
`DifferentialRunnerError`. Map comparison is order-insensitive but one-to-one:
each candidate pair can satisfy at most one reference pair, including when an
adapter supplies malformed duplicate entries. Float
observations are compared exactly by default. Call
`compare_differential_runs(reference, candidate, DifferentialFloatTolerance{...})`
to opt into explicit absolute/relative float tolerance; negative tolerances remain
non-matching, and all non-float values stay exact.

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
fixtures are possible. Child environment overrides are ordered typed
`(name, value)` entries and are applied only after `fork`, so the parent
runner's environment remains unchanged.
The validator also caps the aggregate terminated C-string payload for the
executable, adapter entry, arguments, working directory, and environment at
64 MiB; each environment entry includes the `=` separator materialized by
`setenv`. Staged stdin is capped at 64 MiB. The low-level invocation boundary
repeats these byte checks before reserving or writing host buffers, so bypassing
runner preparation cannot turn a large differential case into an unbounded
allocation.
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

For Python-shaped adapters, the same snapshot can be read with typed fields:
`capture.returncode`/`capture.exit_status`/`capture.status`, `capture.stdout`, and
`capture.stderr` (the explicit `process_*` field spellings are also accepted).
These are aliases over the same one-shot accessors, so field syntax does not
change the differential run or introduce a second process invocation.

The standalone host boundary `execute_differential_process` consumes the same
`DifferentialProcessInvocation` produced by `prepare_differential_process`. It
constructs an argv vector directly (never a shell command), feeds stdin through
a temporary file, captures stdout and stderr independently, and applies an
optional working directory and explicit environment overrides in the child just
before `execvp`; its terminator is cleared with `size_of(uintptr)` so the argv
slot is correct on both 32-bit and 64-bit targets. The timeout is a
bounded wait-poll budget; an expired child is killed and raises
`DifferentialRunnerError.Timeout`. A normal nonzero process status, including
the conventional `126`/`127` setup/exec statuses, remains ordinary
`DifferentialRun.exit_status` data for comparison. Argument vectors are bounded
at one million entries before argv or owned C-string reservation, and environment
override entries use the same bound. The validator reports count and aggregate
byte limits as explicit resource issues; the low-level invocation API repeats
the check before launch.
`max_output_bytes` remains caller-configurable below the default 64 MiB ceiling,
but values above that hard capture budget are rejected before fork; this keeps
temporary-file growth and post-exit materialization bounded even when a caller
bypasses runner preparation.
The poll counter checks the positive budget before incrementing, so a
maximum-width timeout cannot wrap into an unbounded wait. Launch, wait, and capture
failures use `DifferentialRunnerError.Process`. Each captured stream is checked
against the runner's `max_output_bytes` ceiling before allocation; exceeding it
fails the invocation instead of allowing unbounded child output to exhaust the
host. Output files are checked during the wait loop as well as after exit, so a
long-running child is terminated as soon as a stream crosses its ceiling. Each
child creates a private process group before `execvp`; timeout and output-limit
cleanup signal that confirmed group and then reap the leader, preventing
descendants from surviving a failed differential case. If parent-side `setpgid`
is interrupted it is retried through a bounded `EINTR` budget; if it still fails,
cleanup signals only the direct leader so a failed group setup can never
target an unrelated process group. Group setup is best-effort on platforms
without POSIX process groups and those adapters must report that limitation. The
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
capabilities as ordinary script execution.
The in-process adapter rejects nonempty `working_directory`, `environment`,
`stdin`, or `protocol` fields with `DifferentialRunnerError.UnsupportedConfiguration`;
use a process runner when a candidate must execute in a separate configured world.
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
must be nonnegative; NaN never equals anything, equal infinities compare equal,
and an infinity cannot match a finite value through relative scaling.

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
IR `canonical_module_bytes` and `module_fingerprint`. The bytes are a field-wise,
order-sensitive encoding, and the `u64` fingerprint is their stable hash across
the interpreter, bytecode, JIT, native, and Wasm lowerings. A report can therefore
prove that all engines ran the same typed module without depending on host
pointers or backend instruction numbering. The fingerprint is a correlation key
rather than a cryptographic digest; the canonical bytes, verified module, and
source revision remain part of the reproducible artifact.
Persisted metadata should use `canonical_bytecode_artifact_bytes`, the
versioned length-prefixed `ESBC` envelope. Its
`bytecode_artifact_fingerprint` is a deterministic cache/correlation key only;
the artifact still must satisfy `bytecode_artifact_matches_module` against the
exact verified module and capability report before execution.
The bytecode adapter must additionally record `BytecodeCapabilityReport` before
execution and the returned `Execution.engine` afterward. The report includes the
direct/fallback decision and function, instruction, and global counts. A case that
claims independent interpreter/VM evidence fails if the candidate reports
`BytecodeInterpreterFallback`, even when the values happen to match. In-process
`DifferentialRun` values expose this as `engine_known` plus `engine`; external
process runs leave `engine_known` false because their implementation engine is
outside the Elisascript runtime.

The execution boundary now carries a backend-neutral `ExecutionCapability`
snapshot alongside that engine identity. For bytecode runs,
`capability_known` is true and the snapshot preserves `direct_supported`,
`function_count`, `instruction_count`, and `global_count` from the preflight
report. Differential adapters copy those fields into `DifferentialRun` so a
serialized or later comparison record cannot lose the pre-run capability facts.
Reference-interpreter and external-process runs deliberately leave the snapshot
unknown; zero counts must not be interpreted as proof that a module was empty.

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
