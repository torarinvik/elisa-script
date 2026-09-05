# Elisascript capability ledger

This ledger is the tracked companion to the local, ignored
`IMPLEMENTATION_PLAN.md`. It records implementation status without converting
static inspection into runtime evidence. Compiler and test execution is
currently suspended by an explicit resource-safety gate; every entry below
that lacks an execution revision remains unqualified for release.

## Status vocabulary

- **implemented / static** — source and documentation are present and have been
  reviewed without launching the compiler.
- **executed** — a bounded, authorized run has recorded toolchain identity,
  platform, seed, result, and resource metrics.
- **differential verified** — an executed run agrees with an independent oracle
  over values, errors, effects, observations, and process behavior.
- **open** — contract, implementation, or evidence is incomplete.

## Current entries

| Requirement ID | Contract and acceptance surface | Status | Source / revision | Backends | Workflow | Open issue / next action |
|---|---|---|---|---|---|---|
| ES-FE-001 | `.elisascript` source loading, bounded filename/source adapters, deterministic spans, and typed source errors. | implemented / static | `src/ir/source.elisa`, `src/ir/source_file.elisa`, `src/driver/elisascript.elisa`; `52d0c13` | interpreter + bytecode facade | CLI, build tools | Execute lexer/parser/source corpus after reauthorization; add exact diagnostic snapshots. |
| ES-INV-001 | Read-only discovery snapshot covers Python, Perl, AWK, shell-family, and Makefile candidates across the declared coding-project roots, with explicit disposition fields and migration waves. | implemented / static | `docs/migration-inventory.md`; `238e96a` | inventory only | P1 migration planning | Build the per-file machine-readable manifest, assign owners, classify generated/vendored files, and record accepted ports. |
| ES-MOD-001 | Qualified `EsIr`, `EsRuntime`, `EsBytecode`, `EsDriver`, and `EsDifferential` namespaces with deliberate public/private boundaries. | implemented / static | `src/**`; `4b91498`, `34c7d18`, `2bec7a6`, `21c69c5` | all | every workflow | Audit vendored modules and add a collision check to the build manifest. |
| ES-TYPE-001 | Static scalar/container checking, declared effect/error rows, callback capability accounting, and typed builtin lowering. | open | `src/ir/lower_ast.elisa`, vendored semantic sources; `a7b9ac9` | interpreter + bytecode facade | all | Consolidate builtin signatures; complete recursive inference and negative diagnostics. |
| ES-IR-001 | Verified CFG, saturated pool bounds, closed TypeKind validation for table and legacy inline descriptors, bounded recursive TypeTable matching, recursive TypeTable identity, ownership metadata, deterministic canonical bytes, and bounded reference call/handler depth. | implemented / static | `src/ir/{ir_model,ir_verify,type_table,serialize,runtime_model}.elisa`, `src/ir/interpret.elisa`; `350b935`, `477d073`, `60ac4e7`, `f221bb0`, `9909d5b`, `8365d9d`, `3286bc3` | all | cache, tooling, differential | Add heterogeneous tuple/record/variant descriptors and execute malformed-module corpus. |
| ES-VAL-001 | Runtime arrays/maps are flat u32-offset views; aggregate arguments and complete caller-owned storage spans, plus public runtime value-kind admission for nested adapters, fail closed before indexing or publication. | implemented / static | `src/ir/runtime_model.elisa`, `src/ir/interpret.elisa`, `src/bytecode/bytecode.elisa`; `376768d`, `60ac4e7`, `24780ce`, `260c277`, `7c2b284` | interpreter + direct bytecode | data transforms, differential | Run boundary fixtures on supported hosts; add allocation-failure injection. |
| ES-TEXT-001 | Byte-oriented text/bytes distinction, checked concatenation/join/split/regex materialization, overflow-safe separator accumulation and cross-backend count narrowing, bounded regex inputs, matcher work and helper scans, host-stack depth, iterative fixed-width repetition, and replacement output, plus bounded C-string conversion. | implemented / static | `src/ir/interpret.elisa`, `src/bytecode/bytecode.elisa`, vendored string runtime; `f09c05e`, `1bc8f60`, `376768d`, `b417eaf`, `11b74d6`, `b6971ac`, `bf1a634`, `1d960d8`, `0930035`, `9518746`, `1768d07`, `bdd084f`, `860d70c`, `cd7b45f` | interpreter + direct bytecode | shell/Perl/AWK ports | Specify Unicode and grapheme policy; add adversarial regex corpus and execute differential corpus. |
| ES-EFF-001 | Dynamic handler lookup, typed operation IDs, cleanup, bounded resumption, handler installation, and recoverable error-guard depth, unrestricted multi-shot capture validation, continuation-capture metadata validation, closed capture-class and replay-safe-effect validation, fail-closed mutable aggregate snapshots and replay-slice bounds, and `error[...]` propagation. | open | `src/ir/interpret.elisa`, `src/ir/lower_ast.elisa`, `src/ir/ir_verify.elisa`; `7d3c5eb`, `ccd397b`, `467c458`, `b0c646f`, `2fa8c25`, `5d803e2`, `92ca6e1`, `bbbca7a`, `9a207bc`, `7449b6c` | interpreter fallback | supervisors, resource wrappers | Finish dynamic handler semantics and adversarial nested/multi-shot cases. |
| ES-BC-001 | Verified bytecode lowering, direct-subset state machine, explicit fallback identity, versioned `ESBC` metadata, pre-reconstruction block-layout validation, bounded direct-call and recovery-guard depth. | implemented / static | `src/bytecode/bytecode.elisa`, `src/ir/artifact.elisa`; `4238989`, `667bc41`, `f221bb0`, `7449b6c` | direct bytecode + fallback | build/test orchestration | Complete serialized instruction payload/cache identity and run strict direct-only evidence. |
| ES-FS-001 | Shell-free filesystem paths, bounded directory snapshots/globbing and retained path bytes, file read/write/copy, typed host failures, and bounded file-input/runtime-storage sizes. | implemented / static | `src/ir/interpret.elisa`, `src/runtime/*_posix.elisa`, vendored file/runtime helpers; `9bdcfa8`, `e06fd80`, `38d1479`, `c52d3d8`, `d863972` | interpreter + bytecode facade | build graphs, file tools | Add platform matrix and permission/symlink race fixtures. |
| ES-PROC-001 | Typed executable/argv vectors, private process groups, temporary-file capture, timeout polling, output ceilings, overflow-safe aggregate argv/environment-byte and bounded process-input/argument/environment/stage allocation, and cleanup. | implemented / static | `src/ir/interpret.elisa`, `src/testing/differential.elisa`; `320f78f`, `85383ea`, `88d6bad`, `9b72917`, `4f32def`, `6884aa6`, `8bc41e8` | interpreter + external oracle | shell replacement, supervisors | Demonstrate RSS/child-tree watchdog in an isolated authorized harness; quantify polling overshoot. |
| ES-DIFF-001 | Differential runner records values, errors, observations, engine identity, capability metadata, and reproducible artifacts; malformed aggregate fixtures, unknown value kinds, malformed nested runtime values, contradictory strict-engine metadata, oversized process inputs, observation snapshots, owned value pools, deeply nested values, and comparator inputs are rejected with typed errors. | implemented / static | `src/testing/differential.elisa`, `docs/differential-testing.md`; `73657be`, `9b72917`, `ef3f647`, `c5b34e8`, `be07543`, `10ada57`, `14ff501`, `260c277`, `d25fffb` | reference/direct/fallback + external oracle | port validation | Add snapshot schemas, shrinkers, independent oracle adapters, and executed parity runs. |
| ES-CLI-001 | Launcher accepts a `.elisascript` source path and preserves argv elements without shell splitting or expansion. | implemented / static | `src/driver/elisascript.elisa`, `src/ir/runner.elisa`; `52d0c13` | host launcher | daily scripts | Add install/distribution contract and exact exit/diagnostic snapshots. |
| ES-QUAL-001 | G0–G7 release gates: reproducible toolchain, inventory coverage, language contract, frontend/IR integrity, runtime/resource safety, library parity, and migration evidence. | open | `IMPLEMENTATION_PLAN.md` (ignored), this ledger | all | release decision | Reauthorize bounded validation, then fill run evidence for every gate; do not delete legacy scripts early. |

## Evidence record template

Every future executed or differential-verified entry must append a dated record
with: requirement ID; Elisascript revision; compiler source revision and
executable hash; host architecture/OS; dependency revisions; exact command and
working directory; fixture/oracle revision and seed; backend identity; result;
stdout/stderr/error/observation digests; peak RSS and elapsed time; child
process-tree outcome; and any known polling or measurement limitation. A
successful static diff check is recorded as static review, never as execution.
