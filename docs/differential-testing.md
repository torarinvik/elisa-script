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

The first shared comparison primitive is `EsDifferential.compare_differential_runs`.
It compares exit status, named error, stdout, stderr, observation count, and then
each `(trace, value)` pair in that fixed order. It returns a typed
`DifferentialComparison` describing the first difference, including the relevant
text or values; identical runs return `DifferentialDifferenceKind.Equal`. The
comparator is implemented as an explicit Elisa state machine, so it cannot skip a
comparison phase or silently continue after a mismatch.

The executable contract is `EsDifferential.DifferentialRunner`. It is a typed
specification, not a command-string escape hatch: the target, optional entry point,
working directory, stdin, protocol, timeout, required effects, and required errors
are separate fields, while process arguments remain a `darray[sview]`. Call
`validate_differential_runner` before handing the value to an adapter. Its explicit
validation machine checks the name and target, requires an entry for adapter/module
runner kinds, scans every argument for embedded NUL bytes, and requires a positive
timeout. A failed check returns `DifferentialRunnerCheck` with a stable issue kind
and argument index; it does not launch anything.

The current runner kinds are `InProcessFunction`, `NativeProcess`, `PythonAdapter`,
`CAbiFunction`, `WasmModule`, and `Service`. Adapters are responsible for turning a
validated specification into a `DifferentialRun`; keeping that execution layer
separate lets native, Python, and Elisascript adapters share the same deterministic
comparison and artifact machinery.

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
