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

The current static slice also binds canonical SHA-256 digest words into
differential ESDF version-4 manifests when a module identity is available;
legacy version-1/2/3 manifests remain decode-compatible but are explicitly
unbound until migrated. This is recorded in commit `47466a4` and remains
unqualified for executed replay evidence.

The shared builtin registry snapshot now contains 202 global rows, 42 `Text`
receiver rows, 9 `Regex` receiver rows, 6 Map receiver rows, and 5 Array receiver rows. The global count includes the
filesystem, process, environment, stream, scalar, text, and regex facades that
have migrated to descriptor-backed semantic and lowering metadata; generic,
variadic, and aggregate-polymorphic families remain explicitly open below.

The same registry now marks compiler-generated rows with explicit visibility:
`raise` and `resume` consume registry-owned arity/result/callback metadata, and
the private `__fstr` row is excluded from `typed_builtin_names()` while still
driving semantic seeding, inference, and lowering (`bcd2f6d`, `1ec23ba`,
`961855b`, `70d92f6`, `c32c793`, `3df996b`, `00e42e8`). Direct global lowerer
spelling guards are now absent; the compiler-free surface audit treats that
empty set as the intended invariant (`a185cb8`, `fc864a5`).

Dictionary receiver operations now share the registry as `Map.keys()`,
`Map.values()`, `Map.copy()`, `Map.get(key, default)`, `Map.pop(key, default?)`,
and `Map.setdefault(key, default)` rows. Semantic zero-/two-argument checking
and optional-pop arity checking,
source-shadowing precedence, receiver return inference, and both lowerer
receiver shapes consume the same
`MapKeys`/`MapValues`/`CopyMap`/`IndexValid`/`PopMapValue`/`SetDefaultMapValue` metadata;
concrete key/value descriptors remain owned by the structural map type while
recursive generic descriptors remain open.

The existing array `copy()`/`count()`/`find()`/`index()`/`contains()` operations now have
parallel Array receiver rows with registry arity/opcode identity,
source-shadowing precedence, structural array inference, and `CopyArray`,
`ArrayCount`, `ArrayFind`, `ArrayIndex`, and `Contains` verifier coverage;
recursive generic array descriptors remain open.

Differential artifact text and fixed-width lookahead readers now share the
subtraction-safe serialized-slice admission used by ESBC (`1d96bfa`); malformed
length fixtures remain static-only while compiler/runtime validation is paused.

IR metadata now has the bounded, borrowed-view `ESIA` version-2 envelope with
digest words and legacy/length/corruption fixtures (`f2c9693`); cache migration
and execution evidence remain open.

| Requirement ID | Contract and acceptance surface | Status | Source / revision | Backends | Workflow | Open issue / next action |
|---|---|---|---|---|---|---|
| ES-FE-001 | `.elisascript` source loading, bounded filename/source adapters, pre-allocation filename admission, deterministic spans, exact-size short-read retry, bounded C-string terminator scanning, bounded permanent parser/semantic/lowering diagnostic payloads and counts, deterministic payload correlation, bounded source-line/caret excerpts, versioned fingerprint and structural diagnostic snapshot equality, compiler-free field-coverage auditing, and per-phase fixture coverage. | implemented / static | `src/ir/source.elisa`, `src/ir/source_file.elisa`, `src/ir/runner.elisa`, `src/driver/elisascript.elisa`, `scripts/check_diagnostic_snapshot.sh`, `test/ir/elisascript_runner_test.elisa`; `52d0c13`, `4927559`, `8c5ff29`, `3586c64`, `bd2161f`, `aa63e90`, `4a9c864`, `a59be03`, `a8969f1`, `277ce56`, `023dff7`, `621def7`, `1e92a3e`, `cf379e8`, `c7b167a` | interpreter + bytecode facade | CLI, build tools | Execute lexer/parser/source corpus after reauthorization; record exact parser/semantic/lowering diagnostic snapshots. |
| ES-INV-001 | Read-only discovery snapshot covers Python, Perl, AWK, shell-family, and Makefile candidates across the declared coding-project roots, with explicit disposition fields and supplementary executable/shebang/inline-interpreter signals. Candidate and signal traversal fail closed above 200,000 regular files; signal content inspection is limited to 8 MiB files; candidate emission uses a private path list to avoid shell pipeline hangs; candidate filename traversal, signal traversal, and content-search errors now fail closed; a bounded current-repository run records 9 shell candidates and representative acceptance workflows. The partition manifest and coordinator now validate each declared root, run the bounded scanners independently, preserve owner/review metadata, reject duplicate/unsafe/unknown-state manifest rows, and fail closed on malformed or missing partitions. | implemented / static | `docs/{migration-inventory.md,migration-inventory-schema.md,migration-inventory-current.md,migration-project-roots.tsv}`, `scripts/{inventory_candidates,inventory_signals,inventory_project_roots,check_migration_inventory}.sh`; `238e96a`, `e60d5ee`, `9bef671`, `df211b6`, `34cdc79`, `902723e`, `a77eb0f`, `dbc9503`, `cbf1279`, `89ea447`, `f53d475`, `41ba046`, `7bf3d22` | inventory only | P1 migration planning | Review every emitted record, assign owners/dispositions, classify generated/vendored files, and record accepted ports; broad-root scans must stay within measured resource budgets. |
| ES-MOD-001 | Qualified `EsIr`, `EsIrArtifact`, `EsRuntime`, `EsBytecode`, `EsDriver`, and `EsDifferential` namespaces with deliberate public/private boundaries and a compiler-free collision/assembly audit that covers both module declarations and all extension files, rejects unknown extension targets, resolves every literal include relative to its declaring file, checks exhaustive bytecode, source-lowering, and parser diagnostic rendering, and keeps POSIX `@link_name`/`extern` declarations private with no leaked `_impl` calls. | implemented / static | `src/**`, `docs/namespace-manifest.md`, `scripts/check_namespace_manifest.sh`; `4b91498`, `34c7d18`, `2bec7a6`, `21c69c5`, `d49cb15`, `766da70`, `8297597`, `de82262`, `bd2161f`, `a59be03`, `6ced4a1` | all | every workflow | Audit vendored modules and integrate the collision report into the eventual build manifest. |
| ES-TYPE-001 | Static scalar/container checking, declared effect/error rows, callback capability accounting, typed builtin lowering, source-declared effect operation arity plus borrowed payload/result signature spans, simple declared effect result and one-positional-payload checking during lowering for both `perform` and `signal`, exact source-operation payload-arity enforcement, and compiler-free audits that lowerer spellings are seeded and effect signature metadata is not dropped at the semantic boundary. | open | `src/ir/lower_ast.elisa`, `vendor/elisa-compiler/src/semantic/{builtin_registry,check_ufcs_unknown_method,resolve_types_infer,semantic_types,symbols}.elisa`, `scripts/{check_builtin_surface,check_builtin_registry,check_effect_operation_metadata}.sh`, `docs/{builtin-surface,semantics}.md`; `a7b9ac9`, `ad22114`, `cae711b`, `d9a4d7b`, `56f4b28`, `eb201b0`, `bb140b2`, `5370a74`, `0341e31`, `8aa1453`, `a5f1ee3`, `973dad1`, `f75cb75`, `7c8aeb7`, `5d8a7bf`, `a08dff1`, `248cc2f`, `444a0e2`, `67d5346`, `37fe2ff`, `09f47a0`, `4d922e9`, `7ec63f9`, `a0337ec`, `73b15d4`, `37ba738`, `cd39dc9`, `7135146`, `ab1c328`, `b15968c`, `5a57864`, `dac291e`, `f675f2e`, `bcd2f6d`, `1ec23ba`, `961855b`, `70d92f6`, `c32c793`, `3df996b`, `00e42e8`, `2f5826c`, `2f5ca71`, `a0ec9d7`, `a185cb8`, `fc864a5`, `4a24d44` | interpreter + bytecode facade | all | The typed registry now covers 202 global rows plus 42 `Text` and 9 `Regex` receiver rows with semantic arity/argument/return/error/opcode metadata and compiler-free consistency checks; global regex facades use typed text/Regex contracts and structural aggregate results. Global `strip`/`trim`/`lstrip`/`rstrip` aliases share the `TrimText` opcode while preserving both/left/right mode metadata. Global `partition`/`rpartition` and `split_lines`/`splitlines` now consume registry result/arity/opcode metadata and preserve typed `darray[sview]` results. Global `split` now uses an explicit registry named-argument slot for optional signed `i64 maxsplit`, shared by semantic checking and lowering; receiver and global contracts retain their distinct slots. Global `join` now carries a structural `darray[text],text` descriptor, rejects firm non-text arrays in semantic checking through the interned type table, and uses registry result/opcode metadata in lowering. Global `min`/`max` now use variadic orderable/array descriptors with verified `SortArray,Index` lowering while polymorphic inference preserves their concrete element family. Global `keys`/`values` now use dictionary descriptors with verified `MapKeys`/`MapValues` projection opcodes while structural inference preserves concrete key/value arrays. Global `sum`/`product` now use iterable/range plus optional `start` descriptors with verified `Add`/`Multiply` fold primitives while polymorphic inference preserves accumulator types. Global `any`/`all` now use iterable/range descriptors with verified `Equal` result metadata inside short-circuit quantifier lowering. The text semantics documentation now records the distinct global versus receiver `maxsplit` positions. All first-family `Text` length, case, boundary, replacement, trim, join, split-lines, predicate, removal-boundary, aggregate, and emptiness helpers consume receiver-specific registry result/opcode and call-shape metadata, while Regex matching/capture/split/substitution rows use the same source-shadowing and shape gates. The registry audit now also verifies every referenced global and receiver opcode has verifier coverage. Semantic unknown-method admission plus direct/receiver return inference consume the same registry while retaining explicit compatibility/coarse fallbacks for unmigrated methods. Source-declared effect operations now enforce exact payload arity during both perform and signal lowering while builtin/open families remain host-extensible. Migrate remaining text methods, aggregate/variadic/receiver/generic rows, structural container element descriptors, structured effect/error IDs, and verifier compatibility, then add recursive inference; execution evidence remains open. |
| ES-IR-001 | Verified CFG, saturated pool bounds, closed TypeKind and descriptor-child-arity validation for table and legacy inline descriptors, bounded acyclic/topological TypeTable validation and recursive matching, recursive TypeTable identity, bounded IR artifact metadata, ownership metadata, deterministic canonical bytes with recursive u32-count admission, a shared subtraction-safe serialized-slice end helper used by the ESBC borrowed-text reader, a bounded portable SHA-256 digest over canonical bytes, digest-bound ModuleArtifact/ESBC metadata, and bounded reference call/handler depth. | implemented / static | `src/ir/{artifact,ir_model,ir_verify,type_table,serialize,runtime_model}.elisa`, `src/ir/interpret.elisa`, `src/bytecode/bytecode.elisa`, `scripts/check_serialization_bounds.sh`, `test/ir/{elisascript_ir_test,elisascript_bytecode_test}.elisa`; `350b935`, `477d073`, `60ac4e7`, `f221bb0`, `9909d5b`, `8365d9d`, `3286bc3`, `c506b26`, `b75a56`, `8a2e712`, `e26c7e6` plus current static slice | all | cache, tooling, differential | Add heterogeneous tuple/record/variant descriptors, migrate legacy version-1 caches, apply the helper to every future reader, and execute malformed-module corpus. |
| ES-VAL-001 | Runtime arrays/maps are flat u32-offset views; aggregate arguments and complete caller-owned storage spans, public runtime value-kind admission for nested adapters, bounded caller-owned storage pools, and bounded structural equality fail closed before indexing or publication. | implemented / static | `src/ir/runtime_model.elisa`, `src/ir/interpret.elisa`, `src/bytecode/bytecode.elisa`; `376768d`, `60ac4e7`, `24780ce`, `260c277`, `7c2b284`, `965d2fa`, `60542e4` | interpreter + direct bytecode | data transforms, differential | Run boundary fixtures on supported hosts; add allocation-failure injection. |
| ES-TEXT-001 | Byte-oriented text/bytes distinction, checked concatenation/join/split/regex materialization, overflow-safe separator accumulation and cross-backend count narrowing, bounded regex inputs, matcher work and helper scans, host-stack depth, iterative fixed-width repetition, bounded allocating case/concat/join and replacement output, plus bounded C-string conversion including numeric formatter adapters. | implemented / static | `src/ir/interpret.elisa`, `src/bytecode/bytecode.elisa`, vendored string runtime; `f09c05e`, `1bc8f60`, `376768d`, `b417eaf`, `11b74d6`, `b6971ac`, `bf1a634`, `1d960d8`, `0930035`, `9518746`, `1768d07`, `bdd084f`, `860d70`, `cd7b45f`, `1ee6c09`, `6c5f73f` | interpreter + direct bytecode | shell/Perl/AWK ports | Specify Unicode and grapheme policy; add adversarial regex corpus and execute differential corpus. |
| ES-EFF-001 | Dynamic handler lookup with exact-operation and whole-family mask consistency, typed operation IDs, cleanup, bounded resumption, handler installation, and recoverable error-guard depth, unrestricted multi-shot capture validation, continuation-capture metadata validation, closed capture-class and replay-safe-effect validation, static rejection of mutable array/map multi-shot captures, fail-closed mutable aggregate snapshots and replay-slice bounds, `error[...]` propagation, source-preserved effect payload/result signature spans ready for typed operation interning, simple declared result/one-positional-payload enforcement for value-producing `perform` and statement `signal`, and exact payload-arity rejection for source-declared operations during lowering. | open | `src/ir/interpret.elisa`, `src/ir/lower_ast.elisa`, `test/ir/elisascript_ir_test.elisa`, `docs/continuation-policy.md`, `scripts/check_continuation_policy.sh`, `vendor/elisa-compiler/src/parser/parser_decl_effect.elisa`, `vendor/elisa-compiler/src/semantic/check_signal_effect.elisa`; `7d3c5eb`, `ccd397b`, `467c458`, `b0c646f`, `2fa8c25`, `5d803e2`, `92ca6e1`, `bbbca7a`, `9a207bc`, `7449b6c`, `cae711b`, `d9a4d7b`, `56f4b28`, `eb201b0`, `7c8aeb7`, `e4677f2`, `34bc6db` | interpreter fallback | supervisors, resource wrappers | Resolve declaration spans into typed operation/resumption IDs, finish dynamic handler semantics, and execute adversarial nested/multi-shot cases. |
| ES-BC-001 | Verified bytecode lowering, direct-subset state machine, explicit fallback identity, version-2 digest-bound `ESBC` metadata with bounded source revisions and aggregate equality depth, pre-reconstruction block-layout validation, bounded direct-call and recovery-guard depth, aligned writer/reader metadata admission, invalid-fingerprint sentinel, a whole-envelope ceiling, and invalid Path line-operation parity fixtures. | implemented / static | `src/bytecode/bytecode.elisa`, `src/ir/artifact.elisa`, `test/ir/elisascript_bytecode_test.elisa`; `4238989`, `667bc41`, `f221bb0`, `7449b6c`, `5f27773`, `965d2fa`, `8970c8a`, `bd0ff62`, `a2527cf`, `e26c7e6` | direct bytecode + fallback | build/test orchestration | Migrate legacy version-1 caches, complete serialized instruction payload/cache identity, and run strict direct-only evidence. |
| ES-FS-001 | Shell-free filesystem paths, bounded C-string path adapters and libc-returned C-string scans, bounded directory snapshots/globbing and retained path bytes, file read/write/copy with bounded short-read/short-write retry and host byte-count validation, bounded interrupted `readlink` and `readdir` retries, typed host failures, bounded file-input/runtime-storage sizes, typed bounded `FileStream` chunk/line operations with explicit close state, and empty/embedded-NUL Path line-operation parity fixtures. | implemented / static | `src/ir/interpret.elisa`, `src/runtime/*_posix.elisa`, `src/runtime/stream_posix.elisa`, vendored file/runtime helpers, `test/ir/{elisascript_interpreter_test,elisascript_bytecode_test,elisascript_ir_test}.elisa`, `scripts/{check_streaming_file,check_path_line_contract}.sh`; `67a4114`, `9bdcfa8`, `e06fd80`, `38d1479`, `c52c3d8`, `d863972`, `d0524ec`, `6266d7d`, `dfe04f3`, `5c2c35e`, `fb42299`, `8c5ff29`, `91bba99`, `a2527cf` | interpreter + bytecode facade | build graphs, file tools | Add scoped cleanup/lifetime enforcement, platform matrix, and permission/symlink race fixtures. |
| ES-IO-001 | Typed stdin/stdout state machines with explicit 64 MiB input/output ceilings, pre-admission chunk checks, host byte-count validation, bounded short-read/partial-write progress, and bounded retry of interrupted POSIX reads, non-blocking child polls, language sleeps, and poll sleeps. | implemented / static | `src/ir/interpret.elisa`, `src/runtime/{runtime,directory_posix}.elisa`, `docs/{ir,semantics,differential-testing}.md`; `30329a0`, `36a561f`, `af51e50`, `5c2c35e`, `4f0b98f`, `8c5ff29` | interpreter + process adapter | CLI, process ports, differential harnesses | Add interrupted-call fixtures and platform-specific errno adapters after validation reauthorization. |
| ES-RUNTIME-001 | Shared per-run `RuntimeResourcePolicy`/`RuntimeResourceUsage` contract names steps, optional elapsed time, memory, open handles, processes, output bytes, regex work, retained traces, and concurrent tasks; policy-aware interpreter/direct-bytecode entrypoints enforce the shared step budget and return the inherited policy/usage snapshot; in-process differential runs preserve the same metadata while external processes remain unknown. | open / static | `src/ir/runtime_model.elisa`, `src/ir/interpret.elisa`, `src/bytecode/bytecode.elisa`, `src/testing/differential.elisa`, `scripts/check_resource_policy.sh`, `docs/{ir,differential-testing}.md`; `d9187ba`, `04052a2` | interpreter + direct bytecode metadata | all runtime workflows | Thread accounting through every bridge, nested handler/callback/replay path, cancellation, and wall-clock/memory enforcement; execute zero/one/boundary/adverse-resource fixtures after reauthorization. |
| ES-PROC-001 | Typed executable/argv vectors, private process groups, temporary-file capture, timeout polling, hard output ceilings, overflow-safe aggregate argv/environment-byte and bounded process-input/argument/environment/stage allocation, terminated C-string accounting including `setenv` separators, shared interpreter C-string bounds, differential C-string/stdin payload bounds with bounded short-read/short-write retry, host byte-count validation, bounded EINTR cleanup, parent/child-group-admission, and child-redirection retries, verified group-only cleanup with direct-child fallback, and cleanup. | implemented / static | `src/ir/interpret.elisa`, `src/testing/differential.elisa`; `320f78f`, `85383ea`, `88d6bad`, `9b72917`, `4f32def`, `6884aa6`, `8bc41e8`, `5aac066`, `cb0d47f`, `d0524ec`, `27d6c1f`, `8f459c2`, `51c5862`, `dfe04f3`, `5c2c35e`, `b8b0665`, `2f2f06a`, `a63bcf2`, `9d4f1f5`, `442276c`, `8c5ff29` | interpreter + external oracle | shell replacement, supervisors | Demonstrate RSS/child-tree watchdog in an isolated authorized harness; quantify polling overshoot. |
| ES-VAL-002 | Bounded validation wrappers fail closed by default, pin the StructPy compiler path, serialize lowering/test workers with a PID-and-start-identity lease, reject unverifiable live owners, bound temporary compiler diagnostics, snapshot the owned PID set before tree termination, protect metadata with `umask 077`, persist a symlink-safe resource-failure emergency-stop latch, clean up only owned lease/log/process state, and expose a compiler-free wrapper audit for the disabled gate and ownership controls. | implemented / static | `scripts/{run_bounded_lowering,run_bounded_test,stop_bounded_validation,check_validation_wrappers}.sh`, `docs/{development,validation-baseline}.md`; `ce36815`, `995a515`, `757a6ca`, `e774d4a`, `9ea399c`, `3a977db`, `d971da3` | validation tooling | compiler qualification | Keep compiler validation disabled until explicit reauthorization; exercise lease race/stale-owner, log-limit, child-reparent, emergency-latch, and metadata-permission cases only in an isolated synthetic harness. |
| ES-DIFF-001 | Differential runner records values, errors, observations, engine identity, capability metadata, and reproducible artifacts; malformed aggregate fixtures, unknown value kinds, malformed nested runtime values, contradictory strict-engine metadata, cyclic/shared comparison graphs, checked-subtraction array/map snapshot ranges, bounded process text/stdin inputs including explicit owned binary stdin with bounded short staging-read/write retry and host byte-count validation, hard output ceilings, environment separator accounting, bounded source targets, observation snapshots, owned value pools, deeply nested values, comparator inputs, deterministic world fingerprints, typed bounded text/binary world fixtures and stdin, validated world snapshots for order-contamination detection, a typed two-root `Planned → Materialized → Running → Restoring → Restored` world lifecycle, ESDF/ESCR/ESPS/ESRP/ESVP sidecars, exact float payloads, bounded borrowed/allocation-on-read decoders, ESIX Prepared/Complete publication indexes, state-machine replay admission for mixed/stale/incomplete bundles, typed `Staging → Ready → Published` directory publication plans with single-edge transition enforcement, bounded world and run-evidence shrink candidates including explicit binary file/stdin payload clearing that preserves their kinds, closed-language independent oracle admission, and explicit validated comparator policies for text newline handling, map ordering, and float tolerance are rejected with typed errors. | implemented / static | `src/testing/differential.elisa`, `docs/differential-testing.md`, `test/differential/elisascript_differential_test.elisa`; `73657be`, `9b72917`, `ef3f647`, `c5b34e8`, `be07543`, `10ada57`, `14ff501`, `260c277`, `d25fffb`, `08da4e1`, `5aac066`, `cb0d47f`, `da248a2`, `67754aa`, `dfe04f3`, `5c2c35e`, `8c5ff29`, `f24b1f3`, `a7b9031`, `adc9024`, `37f34ee`, `cc3b9da`, `a7f31e1`, `ec49be5`, `a823bb8`, `0e4d000`, `0794004`, `b4b7604`, `d127a31`, `216b15b`, `3968a82`, `8fc30b1`, `e116ba8` | reference/direct/fallback + external oracle | port validation | Add actual world materialization/restore, atomic mkdir/write/fsync/rename, crash recovery, aggregate-value and process termination/timeout shrinkers, oracle adapters, actual replay integration, persist complete normalization policy in artifacts, and executed parity runs. |
| ES-CLI-001 | Launcher accepts a `.elisascript` source path, rejects embedded NULs in source and typed argv, bounds raw `argc` through a shared public derived ceiling, every raw host C-string scan, argv count, aggregate staging, and source-path C-string conversion plus the stricter filename ceiling before allocation and during the raw source-slot scan, preserves argv elements without shell splitting or expansion, enforces argument count/byte budgets again in the public parser, retains parser/semantic/lowering/verifier issue variants and bounded source coordinates plus deterministic payload correlation, renders retained parser/semantic/source/entrypoint/runtime enum variants, bounded parser context and source-line/caret excerpts plus semantic numeric payload counts, first source-lowering issue kinds, first bytecode verifier issue kinds, versioned fingerprint plus structural equality over the complete diagnostic record, compiler-free field-coverage audit, and per-phase snapshot fixtures, preserves a typed source-phase detail for early filename rejection, and retries diagnostic writes across short progress and bounded `EINTR`. | implemented / static | `src/driver/elisascript.elisa`, `src/ir/{runner,runtime_model}.elisa`, `scripts/check_diagnostic_snapshot.sh`, `test/ir/elisascript_runner_test.elisa`; `52d0c13`, `150954d`, `8cd2ce1`, `9e58b9d`, `5a7635e`, `3d7a985`, `739507b`, `9c5bb38`, `81ab6ce`, `5c2c35e`, `f4d25bf`, `f750f16`, `d396f47`, `00f92b2`, `3586c64`, `806c352`, `dcc8049`, `34611a1`, `bd2161f`, `aa63e90`, `4a9c864`, `a59be03`, `36d73f1`, `6fa8fd9`, `a8969f1`, `277ce56`, `621def7`, `1e92a3e`, `cf379e8`, `c7b167a` | host launcher | daily scripts | Add install/distribution contract; execute exact diagnostic snapshot corpus after reauthorization. |
| ES-QUAL-001 | G0–G7 release gates: reproducible toolchain, inventory coverage, language contract, frontend/IR integrity, runtime/resource safety, library parity, and migration evidence. | open | `IMPLEMENTATION_PLAN.md` (ignored), this ledger | all | release decision | Reauthorize bounded validation, then fill run evidence for every gate; do not delete legacy scripts early. |

The ES-TYPE-001 registry slice also includes receiver-aware `Text.contains`
metadata and lowerer consumption (`6d3cd17`); the compiler-free registry audit
checks its semantic/lowerer/verifier path alongside the existing rows.

`Text.count` now follows the same registry-backed semantic, inference, lowerer,
and verifier path with a text needle and `usize` result (`f618e09`).

`Text.find` now follows the registry-backed path with a text needle, `TextFind`
opcode, and signed `i64` miss sentinel (`bf6fce1`).

`Text.rfind` follows the same path with `TextRFind` and the reverse-search
miss sentinel (`5f6b70a`).

`Text.index` and `Text.rindex` now carry receiver-specific `TextIndex`/
`TextRIndex` opcodes and the `IndexOutOfBounds` error row (`36b6684`).

Registry-declared effect/error metadata is now recorded through one lowerer
contract helper at the shared global-call boundary (and the receiver method
boundary), covering `ParseError` conversions and checked text indexing while
preserving future effect rows without another operation-specific push path
(static increment, compiler validation suspended).

`Text.partition` and `Text.rpartition` now carry the `TextPartition` opcode and
fixed text-separator contract while preserving their `darray[sview]` result
shape (`881a636`).

The receiver registry now also covers the zero-argument text emptiness aliases,
with lowerer result metadata preserved for collection and Path compatibility
(`a1f9bfb`).

The receiver registry now also covers `Text.len() -> usize`; its zero-argument
lowerer emits the existing verified `Length` operation, and static fixtures
cover both ordinary dispatch and shadowing by a source `len` function.

The semantic fixture now independently checks the inferred `usize` result and
rejects both a mismatched destination and an extra method argument (`dbcce1f`).

The IR verifier now enforces that every `Opcode.Length` result is the exact
unsigned 64-bit `usize` representation rather than merely any integer kind, and
the same predicate is shared by text/array counts, file size/mode, text/byte
writes, and standard-stream writes; static IR fixtures keep valid `usize`
instructions beside rejected signed results (`8972860`). Compiler and runtime
validation remain suspended.

`Text.split` and `Text.rsplit` now use registry arity, `text,i64` argument
contracts, `Split` opcode metadata, and a declared `maxsplit` named-argument
slot (`cd8ae26`).

Registry receiver diagnostics and lowerer dispatch now give direct source
functions precedence over matching Text spellings, while normalized qualified
builtins apply the same source-name guard (`430cf38`). Generic UFCS lowering
now forwards a shadowing receiver through the ordinary typed direct-call path,
and semantic inference plus arity/named/literal/firm argument checks use the
unique non-seeded source declaration for the same precedence boundary, with
static semantic/lowering fixtures covering valid return rows and rejected
receiver or argument shapes.

The `Text.join` `darray[text]` descriptor now consults the interned container
type table for firm annotated arrays, rejecting known non-text element rows while
leaving unknown expressions conservative (`9ee7cd2`).

Registry `darray[text]` result rows for Text split, line-split, and partition
methods now flow through the structural type channel when the canonical
`darray[sview]` row is interned (`69de436`).

The source-shadowing guard now distinguishes line-zero registry seed symbols
from actual source declarations, so seeded names such as `contains` retain their
receiver contract (`f69d678`).

Global registry rows now receive semantic arity, named-argument, and
scalar/text/collection descriptor checks with the same source-declaration
shadowing rule (`bf5fd4c`).

Receiver return-type inference now applies the source-declaration guard to both
registry rows and legacy Text fallback results (`90a1581`).

Regex receiver lowering and return inference now apply the same source-callable
shadowing guard (`84f3064`). The nine Regex receiver spellings now share typed
registry rows for arity, text arguments, result shape, and opcode; semantic
diagnostics, structural result inference, and lowerer call-shape validation all
consume those rows, including bound Regex receiver classification for `split`,
with compiler-free audit coverage (`a0337ec`, `73b15d4`).

The six canonical global regex facades now use typed registry rows for
text/Regex contracts and aggregate/direct-call result inference (`37ba738`,
`cd39dc9`, `7bb8828`); typed `regex(...)` constructors preserve nominal
`Regex` inference for those checks (`a206d36`).

The effect declaration bridge now resolves nested `array`/`darray`, `set`, and
`dict`/`map` result and one-payload spellings from borrowed source spans, while
leaving malformed, function-type, refinement, and multi-parameter signatures
conservative (`c12c4f8`).

The effect lowerer now parses top-level operation parameter spans and checks every
ordered payload for multi-parameter `perform` and `signal` operations; the existing
IR and handler callback ABI already carry arbitrary operand counts (`dc122b3`),
with static lowering fixtures for matching and mismatched two-parameter effects
(`066d585`).
Statement-form `signal` rejects a source-declared non-void result, preserving the
distinction between fire-and-forget signals and value-producing `perform`
(`93befcb`).
The semantic metadata pass now rejects the same non-void `signal` contract before
lowering, with a focused negative fixture (`9d59c51`).
Same-file `@handler` decorators now check declared operation arity, payload types,
and resumed result types before handler clauses enter the IR (`88756ff`). Source
decorators also copy callback-declared `can[...]` effects and `error[...]` families
into the derived handler descriptor, preserving the host descriptor contract and
preventing capability/error rows from disappearing at the source-to-IR boundary.

Effect-operation metadata now also carries one stable FNV-1a `u64` identity from
parser capture through semantic lookup and lowered IR. Handler clauses and every
operation-bearing instruction preserve the identity; verification accepts zero only
for legacy fixtures and rejects populated ids that disagree with their readable
family/operation names. Runtime dispatch still compares names for compatibility;
the interpreter now prefers matching populated operation IDs for handler clauses and
raised-error guards, with zero as a legacy wildcard. `Resume` instructions and
captured continuation frames now carry a handler-derived resumption token and reject
populated mismatches; richer continuation provenance remains a later migration step.
Canonical IR emission and hashing now include the operation and resumption IDs, so
artifact fingerprints preserve typed dispatch metadata.

The interpreter and direct-bytecode adapters now consume one shared
`ES_RUNTIME_DEFAULT_MAX_EXECUTION_CALL_DEPTH` limit for host-recursive calls and
handler/error-stack depth, with a compiler-free audit and IR fixture preventing
backend drift. The aggregate equality recursion ceiling is centralized there as
well, so interpreter and direct bytecode share the 128-level malformed/cyclic
storage boundary.
Recoverable error-guard nesting is centralized under the same runtime model as a
separate 4,096-entry ceiling, preventing malformed control-flow recovery from
receiving a backend-specific budget.

Persisted artifact envelopes now expose explicit migration signals: ESIA and
ESBC classify the known version-1 records separately from malformed current
metadata, while ESDF manifests report when a valid version-1--3 record still
lacks the digest binding required by version 4. These predicates are advisory
only; current readers remain fail-closed until a deliberate cache/manifest
migration policy is implemented and exercised (`pending`). ESIA/ESBC metadata
labels additionally reject embedded NUL bytes before a host string boundary.
In-memory ESIA/ESBC migration helpers now recompute digest identity from the
verified module and reject stale legacy fingerprints or capability snapshots;
on-disk cache rewrite/restart evidence remains pending. `EsArtifactCache` now
provides bounded file loads plus staged-file/sync/close/rename publication around the
current/migration/invalid admission classifier and explicit
staged/committed/aborted/restart state machine. Directory fsync, crash recovery,
and concurrent-writer evidence remain pending.
The typed `ArtifactCacheWriterLease` now rejects zero, competing, and stale
owner tokens before publication; an OS lock and crash-recovery qualification are
still required. Publication can additionally receive a parent directory and
perform a typed `dirfd`/`fsync`/`closedir` edge after rename; platform lock and
restart evidence remain open. POSIX `_locked` publication wrappers now hold the
advisory lock across staging, file sync, rename, and optional directory sync,
with release on both success and failure; a successful release failure is typed
as a lock error while publication failures retain their original cause. The
lock's `Available → Held → Released` transition table is explicit and permits
reacquisition only from `Released`; invalid events remain inert.

The first large-file vertical slice is now a typed `EsRuntime::FileStream`
contract with explicit modes, bounded chunk read/write, an error-safe line
iterator, idempotent closed-state transitions, and a one-shot
`FileStreamCleanupGuard` commit/abort state machine. Its static audit covers the
shared byte-budget admission and state-machine syntax; compiler-enforced lexical
cleanup/lifetime, platform adapters, and executed large-file evidence remain
open.

Recent static increments are committed as `72f3325` (Path line semantics audit),
`0739d4c` (typed cleanup guard), `b0ecf06` (cache cleanup integration),
`9873d8c` (all resource-policy ceiling admission), `3bd7152` (typed resource
counter edges), `614ad2e` (bounded additive resource edges), `cc418d6`
(interpreter step accounting), `d23ffbd` (configured step ceiling), and `64986ef`
(ESDF version-3 manifest fixture), `1313ba7` (directory fsync), and `957aa55`
(POSIX writer locking), `c91d558` (durable cache arbitration notes), and the
current lock-scoped publication, lock-transition, and checked elapsed-resource
increment. They remain compiler-free evidence while validation is paused.

## Evidence record template

Every future executed or differential-verified entry must append a dated record
with: requirement ID; Elisascript revision; compiler source revision and
executable hash; host architecture/OS; dependency revisions; exact command and
working directory; fixture/oracle revision and seed; backend identity; result;
stdout/stderr/error/observation digests; peak RSS and elapsed time; child
process-tree outcome; and any known polling or measurement limitation. A
successful static diff check is recorded as static review, never as execution.
