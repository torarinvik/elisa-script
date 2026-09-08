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

The interpreter POSIX bridge now admits path operands through a private 4 KiB
length-only check before embedded-NUL scanning, terminator allocation, or host
filesystem calls. Filesystem source/destination, symlink, directory, and child
working-directory paths use the bounded adapter while executable, argument, and
environment text retain the broader shared C-string ceiling. The metadata-only
oversized-path fixture and compiler-free audit are present; execution evidence
remains suspended (`scripts/check_interpreter_paths.sh`).

The differential process bridge applies the same 4 KiB length-first admission to
non-empty `working_directory` values before child-side `chdir`; executable,
entry, argv, and environment fields retain the 64 MiB process-text budget. The
oversized working-directory fixture remains metadata-only and is covered by the
differential compiler-free audit; process execution evidence remains gated.

Temporary-file prefixes now reserve the fixed `/tmp/elisascript-` and six
placeholder bytes inside the same 4 KiB path envelope, rejecting prefixes over
4,072 bytes before NUL/slash scans or `mkstemp`/`mkdtemp` allocation. The
oversized-prefix fixture is metadata-only; host execution evidence remains
gated.

Interpreter glob expansion now rejects oversized path/pattern views before NUL
scans and caps every joined directory/entry path at the same 4 KiB envelope;
the metadata-only oversized-glob fixture is covered by the path audit. Actual
filesystem traversal and platform evidence remain gated.

The current static slice also binds canonical SHA-256 digest words into
differential ESDF version-4 manifests when a module identity is available;
legacy version-1/2/3 manifests remain decode-compatible but are explicitly
unbound until migrated. This is recorded in commit `47466a4` and remains
unqualified for executed replay evidence.

The shared builtin registry snapshot now contains 204 global rows, 42 `Text`
receiver rows, 12 `Regex` receiver rows, 9 Map receiver rows, 4 Set receiver rows, and 14 Array receiver rows. The global count includes the
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
`Map.setdefault(key, default)`, `Map.update(other)`, `Map.remove(key)`, and
`Map.clear()` rows. Semantic
zero-/two-argument checking, optional-pop arity checking, and update shape
checking,
source-shadowing precedence, receiver return inference, and both lowerer
receiver shapes consume the same
`MapKeys`/`MapValues`/`CopyMap`/`IndexValid`/`PopMapValue`/`SetDefaultMapValue`/
`Concat`/`DeleteIndex`/`MakeMap` metadata;
concrete key/value descriptors remain owned by the structural map type while
recursive generic descriptors remain open.
Both backends search for a `PopMap` key before allocating replacement storage,
so an absent-key removal leaves flat storage unchanged.
The same search-before-allocation rule applies to no-op `DeleteIndex` map
removals.
`SetIndex` map updates also preflight the extra pair and reject a full `u32`
storage domain before copying entries. They first search for the key, so a
present-key replacement admits the original pair span without requiring an
unneeded extra slot.
Map concatenation preflights only newly introduced right-hand keys, preserving
valid duplicate-only merges when no additional pair capacity remains.
`PopMap` and `DeleteIndex` likewise preflight only the shortened map after a
match; absent-key no-ops return without requiring replacement capacity.
Glob expansion preflights its deduplicated match count rather than the raw
walker count, preserving valid overlap-heavy expansions at the storage ceiling.
Regex capture and capture-name arrays likewise preflight their exact proven
result count after matcher accounting, avoiding pattern-length over-admission.
Scalar named-capture lookup no longer charges array storage that it never writes.
`SplitLines` now applies the same exact-result admission in both engines rather
than charging the full input length.
General text `Split`/`rsplit` now collect local views and preflight their exact
field count before publishing, including whitespace and empty-separator modes.
`Path.iterdir()` rolls the flat storage cursor back on a late child-path failure,
so directory materialization is failure-atomic. The traversal clears its
scanner handle after `closedir`, preventing reuse of a closed host pointer.
Array/map literal and global initialization paths likewise roll back their entry
cursor when a malformed frame or literal fails during construction.
Global map materialization additionally rejects odd key/value payload lengths at
the runtime boundary, preserving the verifier's pair invariant if a malformed
binding reaches initialization.

Set receiver operations now share the registry as `Set.add(value)`,
`Set.remove(value)`, `Set.discard(value)`, and `Set.clear()` rows. The lowerer
keeps the dedicated `__elisascript_set` marker while semantic arity,
source-shadowing, inference, and verifier coverage use the same
`SetIndex`/`DeleteIndex`/`MakeMap` identities.

The existing array `copy()`/`pop()`/`reverse()`/`sort()`/`insert()`/`remove()`/`push()`/`append()`/`extend()`/`clear()`/`count()`/`find()`/`index()`/`contains()` operations now have
parallel Array receiver rows with registry arity/opcode identity,
source-shadowing precedence, structural array inference, and `CopyArray`,
`PopArrayValue`, `ReverseArray`, `SortArray`, `InsertArray`, `RemoveArray`, `Concat`, `MakeArray`, `ArrayCount`, `ArrayFind`, `ArrayIndex`, and `Contains` verifier coverage;
recursive generic array descriptors remain open.
`SortArray` preflights scalar element homogeneity before copying, keeping malformed
sort failures from publishing partial flat storage in either backend.

Differential artifact text and fixed-width lookahead readers now share the
subtraction-safe serialized-slice admission used by ESBC (`1d96bfa`); malformed
length fixtures remain static-only while compiler/runtime validation is paused.

IR metadata now has the bounded, borrowed-view `ESIA` version-2 envelope with
digest words and legacy/length/corruption fixtures (`f2c9693`); cache migration
and execution evidence remain open.

| Requirement ID | Contract and acceptance surface | Status | Source / revision | Backends | Workflow | Open issue / next action |
|---|---|---|---|---|---|---|
| ES-FE-001 | `.elisascript` source loading, bounded filename/source adapters, pre-allocation filename admission, deterministic spans, exact-size short-read retry, bounded C-string terminator scanning, bounded permanent parser/semantic/lowering diagnostic payloads and counts, deterministic payload correlation, bounded source-line/caret excerpts, versioned fingerprint and structural diagnostic snapshot equality, compiler-free field-coverage auditing, and per-phase fixture coverage. | implemented / static | `src/ir/source.elisa`, `src/ir/source_file.elisa`, `src/ir/runner.elisa`, `src/driver/elisascript.elisa`, `scripts/check_diagnostic_snapshot.sh`, `test/ir/elisascript_runner_test.elisa`; `52d0c13`, `4927559`, `8c5ff29`, `3586c64`, `bd2161f`, `aa63e90`, `4a9c864`, `a59be03`, `a8969f1`, `277ce56`, `023dff7`, `621def7`, `1e92a3e`, `cf379e8`, `c7b167a` | interpreter + bytecode facade | CLI, build tools | Execute lexer/parser/source corpus after reauthorization; record exact parser/semantic/lowering diagnostic snapshots. |
| ES-INV-001 | Read-only discovery snapshot covers Python, Perl, AWK, shell-family, and Makefile candidates across the declared coding-project roots, with explicit disposition fields and supplementary executable/shebang/inline-interpreter signals. Candidate and signal traversal fail closed above 200,000 regular files; signal content inspection is limited to 8 MiB files; candidate emission uses a private path list to avoid shell pipeline hangs; candidate filename traversal, signal traversal, and content-search errors now fail closed; a bounded current-repository run records 9 shell candidates and representative acceptance workflows. The partition manifest and coordinator now preflight header/shape/ownership/duplicate metadata, validate each declared root, canonicalize it with `pwd -P`, reject symlink-resolved roots that escape the configured coding-projects tree, run the bounded scanners independently on canonical in-tree paths, preserve owner/review metadata, reject duplicate/unsafe/unknown-state manifest rows, and fail closed on malformed or missing partitions. | implemented / static | `docs/{migration-inventory.md,migration-inventory-schema.md,migration-inventory-current.md,migration-project-roots.tsv}`, `scripts/{inventory_candidates,inventory_signals,inventory_project_roots,check_migration_inventory}.sh`; `238e96a`, `e60d5ee`, `9bef671`, `df211b6`, `34cdc79`, `902723e`, `a77eb0f`, `dbc9503`, `cbf1279`, `89ea447`, `f53d475`, `41ba046`, `7bf3d22` | inventory only | P1 migration planning | Review every emitted record, assign owners/dispositions, classify generated/vendored files, and record accepted ports; broad-root scans must stay within measured resource budgets. |
| ES-MOD-001 | Qualified `EsIr`, `EsIrArtifact`, `EsRuntime`, `EsBytecode`, `EsDriver`, and `EsDifferential` namespaces with deliberate public/private boundaries and a compiler-free collision/assembly audit that covers both module declarations and all extension files, rejects unknown extension targets, resolves every literal include relative to its declaring file, checks exhaustive bytecode, source-lowering, and parser diagnostic rendering, and keeps POSIX `@link_name`/`extern` declarations private with no leaked `_impl` calls. | implemented / static | `src/**`, `docs/namespace-manifest.md`, `scripts/check_namespace_manifest.sh`; `4b91498`, `34c7d18`, `2bec7a6`, `21c69c5`, `d49cb15`, `766da70`, `8297597`, `de82262`, `bd2161f`, `a59be03`, `6ced4a1` | all | every workflow | Audit vendored modules and integrate the collision report into the eventual build manifest. |
| ES-TYPE-001 | Static scalar/container checking, declared effect/error rows, callback capability accounting, typed builtin lowering, source-declared effect operation arity plus borrowed payload/result signature spans, simple declared effect result and one-positional-payload checking during lowering for both `perform` and `signal`, exact source-operation payload-arity enforcement, and compiler-free audits that lowerer spellings are seeded and effect signature metadata is not dropped at the semantic boundary. | open | `src/ir/lower_ast.elisa`, `vendor/elisa-compiler/src/semantic/{builtin_registry,check_ufcs_unknown_method,resolve_types_infer,semantic_types,symbols}.elisa`, `scripts/{check_builtin_surface,check_builtin_registry,check_effect_operation_metadata}.sh`, `docs/{builtin-surface,semantics}.md`; `a7b9ac9`, `ad22114`, `cae711b`, `d9a4d7b`, `56f4b28`, `eb201b0`, `bb140b2`, `5370a74`, `0341e31`, `8aa1453`, `a5f1ee3`, `973dad1`, `f75cb75`, `7c8aeb7`, `5d8a7bf`, `a08dff1`, `248cc2f`, `444a0e2`, `67d5346`, `37fe2ff`, `09f47a0`, `4d922e9`, `7ec63f9`, `a0337ec`, `73b15d4`, `37ba738`, `cd39dc9`, `7135146`, `ab1c328`, `b15968c`, `5a57864`, `dac291e`, `f675f2e`, `bcd2f6d`, `1ec23ba`, `961855b`, `70d92f6`, `c32c793`, `3df996b`, `00e42e8`, `2f5826c`, `2f5ca71`, `a0ec9d7`, `a185cb8`, `fc864a5`, `4a24d44`, `7687760` | interpreter + bytecode facade | all | The typed registry now covers 204 global rows plus 42 `Text` and 12 `Regex` receiver rows with semantic arity/argument/return/error/opcode metadata and compiler-free consistency checks; global regex facades use typed text/Regex contracts and structural aggregate results. Global `regex_capture_named` and `Regex.capture_named` use `RegexCaptureNamed` and return a unique participating named capture or empty text for missing, ambiguous, or non-participating names. Global `strip`/`trim`/`lstrip`/`rstrip` aliases share the `TrimText` opcode while preserving both/left/right mode metadata. Global `partition`/`rpartition` and `split_lines`/`splitlines` now consume registry result/arity/opcode metadata and preserve typed `darray[sview]` results. Global `split` now uses an explicit registry named-argument slot for optional signed `i64 maxsplit`, shared by semantic checking and lowering; receiver and global contracts retain their distinct slots. Global `join` now carries a structural `darray[text],text` descriptor, rejects firm non-text arrays in semantic checking through the interned type table, and uses registry result/opcode metadata in lowering. Global `min`/`max` now use variadic orderable/array descriptors with verified `SortArray,Index` lowering while polymorphic inference preserves their concrete element family. Global `keys`/`values` now use dictionary descriptors with verified `MapKeys`/`MapValues` projection opcodes while structural inference preserves concrete key/value arrays. Global `sum`/`product` now use iterable/range plus optional `start` descriptors with verified `Add`/`Multiply` fold primitives while polymorphic inference preserves accumulator types. Global `any`/`all` now use iterable/range descriptors with verified `Equal` result metadata inside short-circuit quantifier lowering. The text semantics documentation now records the distinct global versus receiver `maxsplit` positions. All first-family `Text` length, case, boundary, replacement, trim, join, split-lines, predicate, removal-boundary, aggregate, and emptiness helpers consume receiver-specific registry result/opcode and call-shape metadata, while Regex matching/capture/capture-name/split/substitution rows use the same source-shadowing, mode, and shape gates. The registry audit now also verifies every referenced global and receiver opcode has verifier coverage. Filesystem removal aliases now declare the `FileIoError` row emitted by the interpreter, with lowering fixtures checking the propagated error metadata. Semantic unknown-method admission plus direct/receiver return inference consume the same registry while retaining explicit compatibility/coarse fallbacks for unmigrated methods. Source-declared effect operations now enforce exact payload arity during both perform and signal lowering while builtin/open families remain host-extensible. Migrate remaining text methods, aggregate/variadic/receiver/generic rows, structural container element descriptors, structured effect/error IDs, and verifier compatibility, then add recursive inference; execution evidence remains open. |
| ES-IR-001 | Verified CFG, saturated pool bounds, closed TypeKind and descriptor-child-arity validation for table and legacy inline descriptors, bounded acyclic/topological TypeTable validation and recursive matching, subtraction-safe TypeTable child indexing with serialized u32-domain admission, recursive TypeTable identity, construction-time interner admission for closed kinds, child arity, nonzero and child-before-parent ids, bounded IR artifact metadata with nonzero identity admission, ownership metadata, deterministic canonical bytes with recursive u32-count admission plus allocation-free aggregate/text budgeting, a shared subtraction-safe serialized-slice end helper used by the ESBC borrowed-text reader, a bounded portable SHA-256 digest over canonical bytes, digest-bound ModuleArtifact/ESBC metadata, bounded artifact-cache cstr path admission, and bounded reference call/handler depth. | implemented / static | `src/ir/{artifact,artifact_cache,ir_model,ir_verify,type_table,serialize,runtime_model}.elisa`, `src/ir/interpret.elisa`, `src/bytecode/bytecode.elisa`, `scripts/check_serialization_bounds.sh`, `test/ir/{elisascript_ir_test,elisascript_bytecode_test}.elisa`; `350b935`, `477d073`, `60ac4e7`, `f221bb0`, `9909d5b`, `8365d9d`, `3286bc3`, `c506b26`, `b75a56`, `8a2e712`, `e26c7e6`, `7af0669`, `9114050`, `a3a4685`, `4c34f5b` | all | cache, tooling, differential | Add heterogeneous tuple/record/variant descriptors, migrate legacy version-1 caches, apply the helper to every future reader, and execute malformed-module corpus. |
| ES-VAL-001 | Runtime arrays/maps are flat u32-offset views; aggregate arguments and complete caller-owned storage spans, public runtime value-kind admission for nested adapters, bounded caller-owned storage pools, and bounded structural equality fail closed before indexing or publication. | implemented / static | `src/ir/runtime_model.elisa`, `src/ir/interpret.elisa`, `src/bytecode/bytecode.elisa`; `376768d`, `60ac4e7`, `24780ce`, `260c277`, `7c2b284`, `965d2fa`, `60542e4` | interpreter + direct bytecode | data transforms, differential | Run boundary fixtures on supported hosts; add allocation-failure injection. |
| ES-TEXT-001 | Byte-oriented text/bytes distinction, checked concatenation/join/split/regex materialization, overflow-safe separator accumulation and cross-backend count narrowing, bounded regex inputs, matcher work and helper scans, host-stack depth, iterative fixed-width repetition, bounded allocating case/concat/join and replacement output, literal replacement quoting with escaped backslash/dollar/ampersand tokens, plus bounded C-string conversion including numeric formatter adapters. | implemented / static | `src/ir/interpret.elisa`, `src/bytecode/bytecode.elisa`, `scripts/check_regex_replacement.sh`, vendored string runtime; `f09c05e`, `1bc8f60`, `376768d`, `b417eaf`, `11b74d6`, `b6971ac`, `bf1a634`, `1d960d8`, `0930035`, `9518746`, `1768d07`, `bdd084f`, `860d70`, `cd7b45f`, `1ee6c09`, `6c5f73f`, `WORKTREE` | interpreter + direct bytecode | shell/Perl/AWK ports | Specify Unicode and grapheme policy; add adversarial regex corpus, replacement callbacks, and execute differential corpus. |
| ES-EFF-001 | Dynamic handler lookup with exact-operation and whole-family mask consistency, typed operation IDs, cleanup, bounded resumption, handler installation, and recoverable error-guard depth, unrestricted multi-shot capture validation, continuation-capture metadata validation, closed capture-class and replay-safe-effect validation, static rejection of mutable array/map multi-shot captures, fail-closed mutable aggregate snapshots and replay-slice bounds, independent id/value pool starts with paired-count validation and per-pool reclamation, `error[...]` propagation, source-preserved effect payload/result signature spans ready for typed operation interning, simple declared result/one-positional-payload enforcement for value-producing `perform` and statement `signal`, and exact payload-arity rejection for source-declared operations during lowering. | open | `src/ir/interpret.elisa`, `src/ir/lower_ast.elisa`, `test/ir/elisascript_ir_test.elisa`, `test/ir/elisascript_interpreter_test.elisa`, `docs/continuation-policy.md`, `scripts/{check_continuation_policy,check_continuation_pool_slices}.sh`, `vendor/elisa-compiler/src/parser/parser_decl_effect.elisa`, `vendor/elisa-compiler/src/semantic/check_signal_effect.elisa`; `7d3c5eb`, `ccd397b`, `467c458`, `b0c646f`, `2fa8c25`, `5d803e2`, `92ca6e1`, `bbbca7a`, `9a207bc`, `7449b6c`, `cae711b`, `d9a4d7b`, `56f4b28`, `eb201b0`, `7c8aeb7`, `e4677f`, `34bc6db`, `fc6664c`, `WORKTREE` | interpreter fallback | supervisors, resource wrappers | Resolve declaration spans into typed operation/resumption IDs, finish dynamic handler semantics, execute adversarial nested/multi-shot cases, and qualify every backend against the paired-pool contract. |
| ES-BC-001 | Verified bytecode lowering, direct-subset state machine, explicit fallback identity, version-2 digest-bound `ESBC` metadata with bounded source revisions and nonzero identity admission, pre-reconstruction block-layout validation, bounded direct-call and recovery-guard depth, aligned writer/reader metadata admission, invalid-fingerprint sentinel, a whole-envelope ceiling, invalid Path line-operation parity fixtures, and inherited output-ledger accounting across nested direct calls. | implemented / static | `src/bytecode/bytecode.elisa`, `src/ir/artifact.elisa`, `test/ir/elisascript_bytecode_test.elisa`; `4238989`, `667bc41`, `f221bb0`, `7449b6c`, `5f27773`, `965d2fa`, `8970c8a`, `bd0ff62`, `a2527cf`, `e26c7e6`, `4c34f5b`, `a910f89` | direct bytecode + fallback | build/test orchestration | Migrate legacy version-1 caches, complete serialized instruction payload/cache identity, and run strict direct-only evidence. |
| ES-FS-001 | Shell-free filesystem paths, bounded C-string path adapters and libc-returned C-string scans, bounded directory snapshots/globbing and retained path bytes, file read/write/copy with bounded short-read/short-write retry and host byte-count validation, bounded interrupted `readlink` and `readdir` retries, typed host failures, bounded file-input/runtime-storage sizes, typed bounded `FileStream` chunk/line operations whose private line-reader transition checks the remaining budget immediately before every host probe, pure Path-shape inputs/results bounded to the same 4 KiB envelope, explicit close state and bounded host-path admission, per-field process/environment text admission before host scans, and empty/embedded-NUL Path line-operation parity fixtures. | implemented / static | `src/ir/interpret.elisa`, `src/runtime/*_posix.elisa`, `src/runtime/stream_posix.elisa`, vendored file/runtime helpers, `test/ir/{elisascript_interpreter_test,elisascript_bytecode_test,elisascript_ir_test}.elisa`, `scripts/{check_streaming_file,check_path_line_contract,check_process_text_bounds}.sh`; `67a4114`, `9bdcfa8`, `e06fd80`, `38d1479`, `c52c3d8`, `d863972`, `d0524ec`, `6266d7d`, `dfe04f3`, `5c2c35e`, `fb42299`, `8c5ff29`, `91bba99`, `a2527cf`, `86f14b2`, `6c1fbe3`, `5ca4280`, `8b671f9`, `db5e4f5`, `dd8e2b0` | interpreter + bytecode facade | build graphs, file tools | Add scoped cleanup/lifetime enforcement, platform matrix, and permission/symlink race fixtures. |
| ES-FS-002 | EsFileMetadata supplies bounded stat/lstat-shaped snapshots with explicit regular/directory/symlink/other/missing kinds, permission bits, size/inode/device/link identity, timestamps, symlink-target policy, stable ordinals, duplicate-path rejection, clean planned state, path/target/aggregate-byte ceilings, and sealed lookup. The focused IR fixture, namespace inclusion, documentation, and check_file_metadata.sh audit are static evidence; native stat adapters, permission preservation, hardlink creation, race fixtures, and cross-platform execution remain open. |
| ES-FS-003 | EsDirectoryTree supplies a bounded recursive traversal state machine with explicit symlink and failure policies, depth/entry/identity/byte ceilings, stable path identities, cycle/alias rejection, balanced descend/leave scopes, bounded partial-failure accounting, cancellation, and completion. The focused IR fixture, namespace inclusion, documentation, and check_directory_tree.sh audit are static evidence; readdir/stat/copy/remove adapters, hardlink-aware identity policy, race fixtures, and cross-platform execution remain open. |
| ES-SCRIPT-035 | EsRegexCallback supplies a bounded replacement-callback state machine with explicit global/single-match policy, nonzero input/output/capture ceilings, non-overlapping spans, capture ceilings, unmatched-prefix/suffix accounting, callback replacement-byte ceilings, pending-callback exclusion, zero-width progress including EOF non-progress rejection, and typed failure/cancellation. The focused IR fixture, namespace inclusion, documentation, and check_regex_callback.sh audit are static evidence; matcher/callback integration and execution evidence remain open. |
| ES-SCRIPT-036 | EsJsonStream supplies bounded JSON/JSONL framing with input/record/record-count/depth ceilings, a typed delimiter stack with mismatch rejection, quote/escape tracking, newline boundaries only outside strings and balanced containers, exact record-byte boundary admission, final partial-record handling, explicit empty-record policy, and typed unterminated/underflow/cancellation failures. The focused IR fixture, namespace inclusion, documentation, and check_json_stream.sh audit are static evidence; full JSON parsing, schema materialization, and execution evidence remain open. |
| ES-IO-001 | Typed stdin/stdout state machines with explicit 64 MiB input/output ceilings, pre-admission chunk checks, host byte-count validation, bounded short-read/partial-write progress, and bounded retry of interrupted POSIX reads, non-blocking child polls, language sleeps, and poll sleeps. | implemented / static | `src/ir/interpret.elisa`, `src/runtime/{runtime,directory_posix}.elisa`, `docs/{ir,semantics,differential-testing}.md`; `30329a0`, `36a561f`, `af51e50`, `5c2c35e`, `4f0b98f`, `8c5ff29` | interpreter + process adapter | CLI, process ports, differential harnesses | Add interrupted-call fixtures and platform-specific errno adapters after validation reauthorization. |
| ES-RUNTIME-001 | Shared per-run `RuntimeResourcePolicy`/`RuntimeResourceUsage` contract names steps, optional elapsed time, memory, open handles, processes, output bytes, regex work, retained traces, and concurrent tasks; policy-aware interpreter/direct-bytecode entrypoints enforce the shared step budget and return the inherited policy/usage snapshot; compatibility bytecode entrypoints reject step budgets above the shared ceiling; interpreter stdin bulk/line reads cap the host request and count every consumed byte, including delimiters; successful console writes and completed process-capture streams now charge the shared output-byte ledger; reference-interpreter regex operations derive their local matcher budget from the same policy and account newly spent work exactly once; the policy-aware bytecode facade routes caller-specific output/regex limits through the reference interpreter and strict direct-only entrypoints reject unaccounted dimensions; the shared `runtime_resource_policy_has_unaccounted_dimensions` predicate now makes the reference interpreter fail closed on non-default elapsed/memory/handle/process/task limits until host-wide accounting exists; the direct bytecode loop reports bounded console/process-capture output bytes in its default usage snapshot and carries that ledger through nested direct calls exactly once; in-process differential runs preserve the same metadata while external processes remain unknown. | open / static | `src/ir/runtime_model.elisa`, `src/ir/interpret.elisa`, `src/bytecode/bytecode.elisa`, `src/testing/differential.elisa`, `scripts/check_resource_policy.sh`, `docs/{ir,differential-testing}.md`; `d9187ba`, `04052a2`, `2df5b21`, `e064789`, `4166ba2`, `cbacfdc`, `d20f9a4`, `784e8f0`, `17063c2`, `db2cfef`, `a910f89` | interpreter + direct bytecode metadata | all runtime workflows | Thread accounting through every bridge, nested handler/callback/replay path, cancellation, and wall-clock/memory enforcement; execute zero/one/boundary/adverse-resource fixtures after reauthorization. |
| ES-PROC-001 | Typed executable/argv vectors, private process groups, temporary-file capture, timeout polling, cooperative TERM grace followed by forced group KILL/reap, hard output ceilings, overflow-safe aggregate argv/environment-byte and bounded process-input/argument/environment/stage allocation, per-field process/environment text admission before NUL or delimiter scans, terminated C-string accounting including `setenv` separators, shared interpreter C-string bounds, differential C-string/stdin payload bounds with bounded short-read/short-write retry, host byte-count validation, bounded EINTR cleanup, parent/child-group-admission including POSIX `EACCES` confirmation after child-side setup, and child-redirection retries, verified group-only cleanup with direct-child fallback, and cleanup. | implemented / static | `src/ir/interpret.elisa`, `src/testing/differential.elisa`, `scripts/{check_process_text_bounds,check_process_capture,check_process_timeout_mapping,check_process_descendant_cleanup}.sh`; `320f78f`, `85383ea`, `88d6bad`, `9b72917`, `4f32def`, `6884aa6`, `8bc41e8`, `5aac066`, `cb0d47f`, `d0524ec`, `27d6c1f`, `8f459c2`, `51c5862`, `dfe04f3`, `5c2c35e`, `b8b0665`, `2f2f06a`, `a63bcf2`, `9d4f1f5`, `442276c`, `8c5ff29`, `db5e4f5`, `WORKTREE` | interpreter + external oracle | shell replacement, supervisors | The compiler-free process-capture audits now record temporary-file deadlock avoidance, paired stdout/stderr limit checks, bounded timeout polling, typed `InterpretFailure.Time` mapping after output-limit precedence, leader-exit descendant `KILL`, EACCES-aware private-group admission, cooperative/forced group cleanup, and reaping. Demonstrate RSS/child-tree watchdog in an isolated authorized harness; quantify polling overshoot. |
| ES-VAL-002 | Bounded validation wrappers fail closed by default, pin the StructPy compiler path, serialize lowering/test workers with a PID-and-start-identity lease, reject unverifiable live owners, bound temporary compiler diagnostics, require an absolute `setsid` launch into a private compiler process group, aggregate group RSS, snapshot the owned PID set before group/tree termination, protect metadata with `umask 077`, persist a symlink-safe resource-failure emergency-stop latch, signal only private child groups from its verified snapshot, clean up only owned lease/log/process state, and expose a compiler-free wrapper audit for the disabled gate and ownership controls. | implemented / static | `scripts/{run_bounded_lowering,run_bounded_test,stop_bounded_validation,check_validation_wrappers}.sh`, `docs/{development,validation-baseline}.md`; `ce36815`, `995a515`, `757a6ca`, `e774d4a`, `9ea399c`, `3a977db`, `d971da3`, `WORKTREE` | validation tooling | compiler qualification | Keep compiler validation disabled until explicit reauthorization; exercise lease race/stale-owner, log-limit, process-group/reparent cleanup, emergency-latch, and metadata-permission cases only in an isolated synthetic harness; quantify polling overshoot before G0. |
| ES-DIFF-001 | Differential runner records values, errors, observations, engine identity, capability metadata, and reproducible artifacts; malformed aggregate fixtures, unknown value kinds, malformed nested runtime values, contradictory strict-engine metadata, cyclic/shared comparison graphs, checked-subtraction array/map snapshot ranges, bounded process text/stdin inputs including explicit owned binary stdin with bounded short staging-read/write retry and host byte-count validation, hard output ceilings, environment separator accounting, bounded source targets, argument/environment vector admission, observation snapshots, owned value pools, deeply nested values, comparator inputs, deterministic world fingerprints, typed bounded text/binary world fixtures and stdin, validated world snapshots for order-contamination detection, a typed two-root `Planned → Materialized → Running → Restoring → Restored` world lifecycle, ESDF/ESCR/ESPS/ESRP/ESVP sidecars, exact float payloads, bounded borrowed/allocation-on-read decoders with explicit raw-byte enum admission, ESIX Prepared/Complete publication indexes, state-machine replay admission for mixed/stale/incomplete bundles, typed `Staging → Ready → Published` directory publication plans with single-edge transition enforcement, bounded world and run-evidence shrink candidates including explicit binary file/stdin payload clearing that preserves their kinds, closed-language independent oracle admission, and explicit validated comparator policies for text newline handling, map ordering, and float tolerance are rejected with typed errors. | implemented / static | `src/testing/differential.elisa`, `docs/differential-testing.md`, `test/differential/elisascript_differential_test.elisa`; `73657be`, `9b72917`, `ef3f647`, `c5b34e8`, `be07543`, `10ada57`, `14ff501`, `260c277`, `d25fffb`, `08da4e1`, `5aac066`, `cb0d47f`, `da248a2`, `67754aa`, `dfe04f3`, `5c2c35e`, `8c5ff29`, `f24b1f3`, `a7b9031`, `adc9024`, `37f34ee`, `cc3b9da`, `a7f31e1`, `ec49be5`, `a823bb8`, `0e4d000`, `0794004`, `b4b7604`, `d127a31`, `216b15b`, `3968a82`, `8fc30b1`, `e116ba8`, `28866a6`, `7f62ec0`, `3541f79`, `3e996a6`, `c49f746`, `7964a6b` | reference/direct/fallback + external oracle | port validation | Add actual world materialization/restore, atomic mkdir/write/fsync/rename, crash recovery, aggregate-value and process termination/timeout shrinkers, oracle adapters, actual replay integration, persist complete normalization policy in artifacts, and executed parity runs. |
| ES-CLI-001 | Launcher accepts a `.elisascript` source path, rejects embedded NULs in source and typed argv, bounds raw `argc` through a shared public derived ceiling, every raw host C-string scan, argv count, aggregate staging, and source-path C-string conversion plus the stricter filename ceiling before allocation and during the raw source-slot scan, preserves argv elements without shell splitting or expansion, enforces argument count/byte budgets again in the public parser, retains parser/semantic/lowering/verifier issue variants and bounded source coordinates plus deterministic payload correlation, renders retained parser/semantic/source/entrypoint/runtime enum variants, bounded parser context and source-line/caret excerpts plus semantic numeric payload counts, first source-lowering issue kinds, first bytecode verifier issue kinds, versioned fingerprint plus structural equality over the complete diagnostic record, compiler-free field-coverage audit, and per-phase snapshot fixtures, preserves a typed source-phase detail for early filename rejection, and retries diagnostic writes across short progress and bounded `EINTR`. | implemented / static | `src/driver/elisascript.elisa`, `src/ir/{runner,runtime_model}.elisa`, `scripts/check_diagnostic_snapshot.sh`, `test/ir/elisascript_runner_test.elisa`; `52d0c13`, `150954d`, `8cd2ce1`, `9e58b9d`, `5a7635e`, `3d7a985`, `739507b`, `9c5bb38`, `81ab6ce`, `5c2c35e`, `f4d25bf`, `f750f16`, `d396f47`, `00f92b2`, `3586c64`, `806c352`, `dcc8049`, `34611a1`, `bd2161f`, `aa63e90`, `4a9c864`, `a59be03`, `36d73f1`, `6fa8fd9`, `a8969f1`, `277ce56`, `621def7`, `1e92a3e`, `cf379e8`, `c7b167a` | host launcher | daily scripts | Add install/distribution contract; execute exact diagnostic snapshot corpus after reauthorization. |
| ES-SCRIPT-001 | Typed scripting-product contracts now cover explicit module visibility/graph resolution, launcher modes and option boundaries, package manifests/lockfiles with offline/integrity policy, bounded JSON/JSONL/CSV/TSV decoder policy plus namespaced non-recursive JSON node tables, typed schema binding, and quote-aware CSV/TSV streaming, source-map identity and lookup, Human/JSON/JUnit output documents, install/publication rollback, shell-free build graphs, differential lockstep checkpoints/first divergence, and resource ownership/cleanup ledgers. Each contract has public/private namespace boundaries, bounded limits, `error[...]` validation, state-machine transitions, focused fixtures, and a compiler-free audit. | implemented / static | `src/runtime/{module,cli,package,data,json,schema,csv,source_map,output,install,build,resource}_model.elisa`, `src/testing/sequence_model.elisa`, `src/driver/elisascript.elisa`, `src/ir/{ir,runner}.elisa`, `scripts/{check_cli_model,check_package_model,check_data_model,check_json_model,check_schema_model,check_csv_model,check_source_map_model,check_output_model,check_install_model,check_build_model,check_resource_model,check_differential_sequence}.sh`, focused IR/differential fixtures; `a392c80`, `e9ff9eb`, `011abf3`, `e4e2627`, `cc06efa`, `e8fe8c9`, `9b34fe4`, `6f8ed64`, `7311aff`, `7aa74ba`, `920114c`, `912b9a1`, `48c4152`, `WORKTREE` | contracts only; host adapters pending | CLI/package/data/build/differential workflows | Implement parser/renderer/registry/cache/scheduler/host-handle adapters, connect full CLI modes, add vendor-parser/schema conversion, CSV/TSV field materialization/newline variants, and obtain bounded compiler/runtime/differential evidence after reauthorization. |
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
shadowing guard (`84f3064`). The twelve Regex receiver spellings now share typed
registry rows for arity, text arguments, result shape, and opcode; semantic
diagnostics, structural result inference, and lowerer call-shape validation all
consume those rows, including bound Regex receiver classification for `split`,
with compiler-free audit coverage (`a0337ec`, `73b15d4`).

The `RegexCapture` contract now admits flat `?`-optional groups: unmatched
groups preserve empty positional slots, while `Regex.capture_names` reports
stable positional names for the same proven layout; nested/repeated/alternating
layouts remain fail-closed (`WORKTREE`).

`Regex.count(text)` is also registry-backed as a `RegexFind,Length` composition
returning `usize`, with semantic, lowering, and interpreter/direct-bytecode
fixtures (`WORKTREE`).

The pattern-first global `regex_count(pattern, text)` shares that
`RegexFind,Length` composition and is covered by semantic/lowering and
interpreter/direct-bytecode parity fixtures (`WORKTREE`).

`RegexSplit` and `RegexFind` roll back their shared storage cursor when matcher
work exhausts after partial span discovery, preventing failed regex operations
from publishing partial arrays.
Both now collect spans locally and preflight the exact result count before
publishing, so long inputs with few matches do not over-admit by text length.

`Regex.capture_named(text, name)` and `regex_capture_named(pattern, name, text)`
now use the verified `RegexCaptureNamed` operation. They return the unique
participating named capture from the first match and fail closed to empty text
for missing, ambiguous, or non-participating names; semantic/lowering,
interpreter, direct-bytecode, and registry-audit fixtures cover both spellings
(`WORKTREE`).

The eight canonical global regex facades now use typed registry rows for
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
provides bounded file loads with exact post-read byte-count admission plus
staged-file/sync/close/rename publication around the
current/migration/invalid admission classifier and explicit
staged/committed/aborted/restart state machine. Directory fsync, crash recovery,
and concurrent-writer evidence remain pending. The pure
`artifact_cache_recovery_action` state machine now makes restart choices
explicit (keep only a validated commit, remove uncommitted staging, rebuild a
missing/invalid destination, or no-op) without performing filesystem mutation;
host recovery and executed evidence remain pending.
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
Cache publication also rejects equal staging/destination paths and lock/data
aliases with typed `ArtifactCacheIoError.PathCollision` before opening or
truncating any cache file.

The interpreter's `CopyPath` edge now rejects an exactly identical source and
destination before opening the destination with truncating write, and compares
existing device/inode identity so hard-link or symlink aliases cannot destroy
the source before its bytes are read. The focused compiler-free copy-path audit
records this admission boundary.

Interpreter-wide exact-size stdio reads and writes now reject zero/over-counted
progress and a positive count accompanied by the host `ferror` indicator before
publishing a value; the process-capture audit records the shared helper
boundary.

The `.elisascript` source-file loader applies the same exact-size read admission
and rejects a sticky host `ferror` before source bytes enter permanent storage;
its focused source-file I/O audit records the boundary.

The differential runner's temporary stdin writer and the interpreter's process
stdin writer apply the same `ferror` admission after every positive short write,
so failed input staging cannot be mistaken for a complete payload.
Its exact-size stdout/stderr reader applies the same admission after positive
short reads, preserving typed process failure for a sticky temporary-file error.

The first large-file vertical slice is now a typed `EsRuntime::FileStream`
contract with explicit modes, bounded chunk read/write, an error-safe line
iterator, idempotent closed-state transitions, and a one-shot
`FileStreamCleanupGuard` commit/abort state machine. Chunk writes now expose a
public transition contract that retries positive short `fwrite` progress from
the advanced offset and rejects zero or over-counted host reports before
publication. A positive count accompanied by the stdio error indicator is also
typed as a write failure instead of being retried. Record reads now expose explicit LF-only, universal-newline, and
retained-delimiter modes with a bounded pending-byte slot for lone-CR handling.
Chunk reads consume that pending slot before any host probe, preserving bytes
when callers switch between record and chunk APIs. Its static audit covers the
shared byte-budget admission and state-machine syntax; compiler-enforced
lexical cleanup/lifetime, platform adapters, and executed large-file evidence
remain open. Typed `tell`/`seek` now correct logical positions around pending
lookahead and make begin/current/end origin semantics explicit; host seek
failure and cross-platform text-position qualification remain open. Sync now
flushes the stdio buffer before descriptor durability and rejects read-mode
sync requests; libc flush and descriptor failures are separate typed paths.
Chunk and byte reads reject a positive `fread` count with the host error
indicator before advancing stream accounting, and EOF checks retain incomplete
UTF-8 state even when a pending lookahead byte filled part of the chunk.
The stream now also carries an explicit `Auto`/`Bytes`/`Utf8` encoding policy,
with incremental strict-UTF-8 validation for text streams and byte-preserving
binary operation; split three- and four-byte continuation bounds are explicit
in the IR fixture, and invalid or incomplete sequences remain typed failures.
Staged publication now has a reusable typed rename edge with optional parent
directory sync; equal staging and destination paths are rejected with typed
`FileStreamError.PathCollision` before the host rename, rename and
directory-sync failures remain separate, and the caller retains ownership of
staging cleanup.
Source loading and text streams now share the public `EsEncoding::Utf8Cursor`
validator; invalid or incomplete source bytes fail before parser allocation as
`ElisascriptSourceError.InvalidUtf8`, while binary stream modes remain raw bytes.

The direct bytecode resource slice now shares one mutable output ledger through
nested calls, including child output emitted before a recoverable error. The
parent usage snapshot therefore cannot reset or double-count nested captures;
the regression fixture and compiler-free audit are recorded in `0d1bf9c`.

The line-file parity slice now pins the distinction between `read_lines` (which
preserves a trailing empty field through `ReadText + Split`) and `split_lines`
(which follows delimiter-oriented Python behavior). Interpreter and direct
bytecode fixtures cover a file ending in a newline, recorded in `8e69ada`.

Recursive tree-copy admission rejects a source-equal or normalized lexical
descendant destination before filesystem mutation. It now also canonicalizes the
existing source and destination parent through the POSIX `realpath` adapter, so
destination-parent symlink aliases into the source tree are rejected before
`mkdir`; the final destination leaf may be absent. The interpreter/direct-bytecode
parity fixtures and path contract audit record both boundaries (`WORKTREE`),
while host canonicalization and execution evidence remain unqualified.

The semantic registry now has a dedicated negative fixture for `copy_tree`'s two
nominal `Path` operands, keeping recursive-copy aliases aligned with the existing
`copy_path` diagnostics (`WORKTREE`).

Builtin copy metadata now preserves independent read/write effect slots from the
registry through seeded semantic symbols and indexed lowerer propagation. The
compiler-free `check_builtin_effect_metadata.sh` audit pins both permissions at
the registry, semantic, lowerer, verifier, and documentation boundaries; general
effect-ID migration and executed validation remain open.

Multi-shot handler verification now walks interned TypeTable child descriptors
with a bounded fail-closed traversal, rejecting nested array/map storage rather
than only root aggregate captures. Legacy inline descriptors retain the root-kind
guard; a malformed nominal-root regression fixture proves the nested guard emits
an `UnsafeMultiShot` issue alongside the structural table error. Deep cloning and
adversarial execution evidence remain open.

Recent static increments are committed as `72f3325` (Path line semantics audit),
`0739d4c` (typed cleanup guard), `b0ecf06` (cache cleanup integration),
`9873d8c` (all resource-policy ceiling admission), `3bd7152` (typed resource
counter edges), `614ad2e` (bounded additive resource edges), `cc418d6`
(interpreter step accounting), `d23ffbd` (configured step ceiling), and `64986ef`
(ESDF version-3 manifest fixture), `1313ba7` (directory fsync), and `957aa55`
(POSIX writer locking), `c91d558` (durable cache arbitration notes), and the
current lock-scoped publication, lock-transition, and checked elapsed-resource
increment. They remain compiler-free evidence while validation is paused.

The runtime policy slice also exposes `runtime_resource_remaining_policy`, a
pure saturating subtraction helper for child, callback, and replay admission.
It preserves the zero elapsed-time "timer not attached" sentinel and returns
zero capacity for every exhausted dimension, so a nested boundary cannot turn
an already-consumed parent budget into a wrapped child allowance. This remains
static policy evidence until every host bridge actually consumes the derived
policy and execution tests are reauthorized.

`EsProcess::ProcessCommand` now supplies a typed shell-free command record with
ordered argv/environment vectors, child cwd, explicit stdio modes, timeout and
failure policy fields, and a bounded `error[ProcessCommandError]` validator.
The differential process adapter materializes every invocation through this
validator before fork/exec, while retaining binary stdin as a length-delimited
side channel. It is still static adapter-boundary evidence only; platform process
creation, background jobs, and streaming callback execution remain open.
`ProcessResult` now supplies the corresponding closed outcome vocabulary for
normal exits, signal death, spawn/timeout/cancellation/output-limit/host-I/O
failures, with bounded stdout/stderr/error payloads and signal consistency
validation through `error[ProcessResultError]`.
`ProcessJob` adds a typed background-supervision state machine with bounded
attempts, explicit cancellation acknowledgement, and typed invalid-transition
or retry-exhaustion errors; actual scheduling, fan-out, and platform signal
escalation remain open. `ProcessPipeline` now validates ordered stage commands,
bounded stage/buffer limits, fail-fast versus aggregate failure policy, and
explicit stage/cancel transitions; concurrent pipe draining and reaping remain
open.
`EsProcessOutput` adds a bounded shell-redirection contract for inherit/null,
capture, truncate, append, and explicit tee fan-out. Destination paths,
duplicate routes, chunk sequencing, final markers, and output ceilings are
validated under `error[ProcessOutputError]`; the focused IR fixture, namespace
inclusion, documentation, and check_process_output.sh audit are static
evidence, while descriptor writes and concurrent drains remain host work.
`EsTask::TaskScope` and `TaskChannel` add bounded child accounting and
message-level backpressure with explicit close/cancel acknowledgement edges;
channel validation reconciles zero/nonzero message and byte aggregates and
rejects an empty imported Closing state;
thread/event-loop scheduling remains open. `EsTaskTransfer` adds a bounded
copy/move/borrow ownership contract for values and dynamic handler contexts;
linear values cannot be copied or borrowed, move updates ownership only at
commit, and handler-context borrows require a finite lease. The focused IR
fixture, namespace inclusion, documentation, and check_task_transfer.sh audit
are static evidence; scheduler integration and runtime transport remain open.

ES-SCRIPT-042 | EsValueOwnership supplies a bounded arena-independent runtime
ownership ledger. It tracks value/arena/owner/generation identities, admits only
initially owned values, and supports linear and borrowed-view kinds, finite borrow leases, active-value/borrow counts, retained
bytes, generation-checked moves, and byte-reclaiming drops with zeroed dropped
payloads. Borrow conflicts,
stale generations, duplicate ids, owner mismatches, double-end, and accounting
drift are explicit under `error[ValueOwnershipError]`. The focused IR fixture,
namespace inclusion, documentation, and check_value_ownership.sh audit are
static evidence; allocator integration, compiler-enforced lifetimes, and
adverse-resource execution remain open.

ES-SCRIPT-043 | EsErrorProvenance supplies a bounded cross-boundary error
envelope. It preserves origin, phase, code, source coordinates, bounded text,
retryability, and earlier cause identity across capture/forward/handle/cancel
edges; future/self causes, cause-depth overflow, duplicate envelopes, origin
reclassification, retained-text overflow, and post-terminal transitions are
typed under `error[ErrorProvenanceError]`. The focused IR fixture, namespace
inclusion, documentation, and check_error_provenance.sh audit are static
evidence; driver/host adapter integration and executed diagnostics remain open.

ES-SCRIPT-044 | EsCancellation supplies a bounded cooperative-cancellation
contract for VM safe points and blocking host boundaries. Parent/child token
ownership, reason text, poll counts, and per-state accounting are validated;
`Request → Propagate → Acknowledge → Complete` and `Fail` transitions are
explicit, requested tokens propagate at VM checkpoints, and a
`HostBeforeBlock` poll rejects blocking work with `HostBlockDenied`. The
focused IR fixture, namespace inclusion, documentation, and
check_cancellation.sh audit are compiler-free static evidence; scheduler
propagation, signal adapters, blocking I/O interruption, and runtime evidence
remain open.

ES-SCRIPT-045 | EsTelemetry supplies an opt-out bounded metrics/tracing
contract. Disabled/counters/events modes are explicit; metric identities,
caller-owned names, payload bytes, sampled sequence numbers, total event
ceilings, ready-state cleanliness, and span-depth accounting are validated.
Sampled-out events still consume the event ceiling and sequence accounting;
sampled-out span edges still update logical depth, and sealing rejects open
spans through `error[TelemetryError]`.
Failure is allowed before sealing but cannot be repeated after the ledger is
already failed.
The focused IR fixture, namespace inclusion, documentation, and
check_telemetry.sh audit are compiler-free static evidence; clock adapters,
export formats, cross-task aggregation, and runtime overhead measurements
remain open.

ES-SCRIPT-046 | EsStructuredTask supplies a bounded structured-concurrency
contract for scheduler adapters. Child ownership and counts, empty planned
scopes, fail-fast versus aggregate failure, state-consistent shielded cleanup
depth, cancellation
acknowledgement, and terminal join outcomes are explicit state-machine edges.
Acknowledgement while a child is cleaning is rejected, and join cannot finish
until active children are zero. The focused IR fixture, namespace inclusion,
documentation, and check_structured_task.sh audit are compiler-free static
evidence; scheduler queues, thread/task adapters, and runtime execution remain
open.

ES-SCRIPT-047 | EsExitStatus supplies a stable launcher/process-status mapping.
Success, bounded user `main -> i64` statuses, usage/source/check/test/script/
host/limit/cancellation outcomes, and signal death are distinct typed cases;
reserved codes are fixed, user codes are restricted to `0..123`, success/user/
signal cases reject diagnostic detail, and signal codes are bounded `128 + signal`
values. The focused IR fixture, namespace
inclusion, documentation, and check_exit_status.sh audit are compiler-free
static evidence; platform exit-width differences, launcher integration, and
executed process-status parity remain open.

ES-SCRIPT-048 | EsDeadline supplies a monotonic host/virtual deadline clock
contract. Clock mode, wait ownership, pending/ready/cancelled accounting,
strictly positive bounded advances, deterministic global due-fire ordering, cancellation, and seal
preconditions are explicit; pending waits cannot be silently dropped, ready
waits cannot be future-dated, and time cannot move backwards. The focused IR
fixture, namespace inclusion,
documentation, and check_deadline.sh audit are compiler-free static evidence;
platform clock sampling, timer integration, and cross-host wakeup parity remain
open.

ES-SCRIPT-049 | EsDebugger supplies a bounded debugger-session contract with
acyclic replay-branch parents.
Breakpoints, source locations, stack frames, handler/continuation depths,
nonempty replay branches, attach/pause/continue/step, frame push/pop, branch selection,
termination, and failure are explicitly validated state-machine edges.
Failure requires an attached active session; terminal sessions cannot resume, and
names/locations/depths are bounded before
publication. The focused IR fixture, namespace inclusion, documentation, and
check_debugger.sh audit are compiler-free static evidence; source-map/runtime
value adapters, pause delivery, and interactive execution remain open.

ES-SCRIPT-050 | EsArchive supplies bounded tar/zip extraction admission.
Relative path validation rejects absolute paths, backslashes, empty/dot/
traversal segments, embedded NULs, and oversized names; entry count, per-entry
and subtraction-safe aggregate bytes, duplicate identities/paths, link policy, planned-state
cleanliness, and commit/fail/cancel lifecycle are explicit. The focused IR fixture, namespace inclusion,
documentation, and check_archive.sh audit are compiler-free static evidence;
format decoders, filesystem writes, overwrite/permission behavior, atomic
publication, and extraction parity remain open. Failure is admitted only from
active extraction; planned and already-failed sessions reject the edge.

ES-SCRIPT-051 | EsHash supplies a bounded incremental integrity contract.
Algorithm identity (`Sha256`, `Sha512`, or `Fnv1a64`), input/chunk ceilings,
chunk counts, one-way begin/update/finalize/fail transitions, canonical digest
word shape, clean planned-state accounting, zeroed unpublished digest payloads,
paired chunk/byte accounting, and algorithm matching are explicit.
The focused IR fixture, namespace
inclusion, documentation, and check_hash.sh audit are compiler-free static
evidence; cryptographic implementation, streaming adapters, package/archive
integration, and cross-platform digest parity remain open.

ES-SCRIPT-052 | EsBinary supplies a bounded binary-cursor contract. Input and
read-count ceilings, explicit little/big endianness, checked u8/u16/u32/u64 reads,
bounded skips, truncation and state errors, impossible offset/read accounting,
and explicit no-trailing-bytes finish validation are represented through
`error[BinaryError]`. The focused IR fixture,
namespace inclusion, documentation, and check_binary.sh audit are
compiler-free static evidence; format-specific decoders, streaming adapters,
and cross-platform binary parity remain open.

ES-SCRIPT-040 | EsTaskTransfer supplies a bounded ownership protocol for
copyable values, linear values, and dynamic handler contexts crossing task
boundaries. Copy/move/borrow modes, source/target owners, generation updates,
finite borrow leases, duplicate-resource rejection, state-specific item-vector
cardinality, admission accounting, and all-items commit/cancel edges are
explicit under `error[TaskTransferError]`.
The focused IR fixture, namespace inclusion, documentation, and
check_task_transfer.sh audit are static evidence; scheduler integration,
message transport, and runtime ownership tables remain open.

ES-SCRIPT-041 | EsExecutable supplies a bounded shell-free executable-discovery
contract. It keeps command names, PATH entries, candidate indices within the
PATH, regular-file and executable observations, selected executable identity,
and exhausted Missing outcomes distinct under `error[ExecutableDiscoveryError]`.
The focused IR
fixture, namespace inclusion, documentation, and check_executable.sh audit are
static evidence; PATH access, permission/stat calls, platform search rules, and
process-launch integration remain open.

`EsRecord::RecordStreamPolicy`, `Record`, and `RecordField` now define a bounded
Perl/AWK-style record boundary: separator and field modes are explicit, fixed
widths and schema names are validated, and source/filename/record-number/
file-number/byte-offset metadata remains attached to each raw record. The
compiler-free IR fixture and record-model audit cover NUL/length/range admission;
stream readers, external sort, lifecycle hooks, and transactional in-place edits
remain open.

`EsNetwork::NetworkRequest` and `NetworkResponse` now define a bounded,
transport-neutral HTTP/TLS contract with explicit methods, ordered headers,
binary bodies, timeout/response ceilings, redirect policy, and distinct DNS,
TLS, transport, timeout, protocol, status, decode, and cancellation outcomes.
`NetworkRetryPolicy` makes retries explicit and bounded: `Never` is one-shot,
`IdempotentOnly` admits only GET/HEAD/PUT/DELETE, and mutation retries require
`Explicit` mode plus nonzero backoff. `network_retry_backoff_micros` derives
one-based attempt delays with checked doubling and saturation at the configured
ceiling. The IR fixture and network-model audit
cover URL/header/body/status/retry admission plus a
`Planned → Resolving → Connecting → Securing → Sending → Receiving → Completed`
request lifecycle with explicit cancellation and retry edges; socket/TLS
implementations now receive an explicit system/custom/test-only trust policy
shape with paired client identity paths; certificate validation, streaming, and
live service adapters remain open. `NetworkStream`/`NetworkChunk` now supply a
bounded, sequence-checked pause/resume buffer contract with explicit drain and
cancel edges for those adapters.

## Evidence record template

Every future executed or differential-verified entry must append a dated record
with: requirement ID; Elisascript revision; compiler source revision and
executable hash; host architecture/OS; dependency revisions; exact command and
working directory; fixture/oracle revision and seed; backend identity; result;
stdout/stderr/error/observation digests; peak RSS and elapsed time; child
process-tree outcome; and any known polling or measurement limitation. A
successful static diff check is recorded as static review, never as execution.

ES-SCRIPT-002 | EsBuildScheduler supplies deterministic dependency-ready
queues with clean ready-state admission, exact fingerprint cache admission, bounded parallel dispatch,
completion/failure accounting, queue-gated cache hits, and cancellation transitions over EsBuild.
Failure is fail-closed while active siblings remain; an admitted failure cancels
remaining planned nodes, clears the ready queue, and requires all terminal
ledgers to account for every graph node.
The focused IR fixture, namespace inclusion, documentation, and
check_build_scheduler.sh audit are static evidence; process launch, cache
persistence, and host cancellation adapters remain open.

ES-SCRIPT-003 | EsOutputRender supplies sealed-document admission at validation,
ordered record consumption, format framing, JSON/XML escape expansion accounting,
shared output-budget enforcement, and explicit failure/cancellation edges.
The focused IR fixture and check_output_renderer.sh audit are static evidence;
actual stdout/stderr writes remain a host-adapter follow-up.

ES-SCRIPT-004 | EsPackageRegistry supplies bounded candidate rows, deterministic
ordering, integrity admission, sealed-state lookup by PackageConstraint, and
loading-only failure/cancellation transitions. The focused IR fixture and
check_package_registry.sh audit are static evidence; network, signature, and
cache persistence adapters remain open.

ES-SCRIPT-005 | EsPackageCache supplies bounded ordered entries, aggregate
byte admission, integrity/fingerprint identity, sealed exact lookup, explicit
invalidation, loading-only failure, and typed cache-miss/reset transitions. The focused IR fixture
and check_package_cache.sh audit are static evidence; atomic host persistence
and crash recovery remain open.

ES-SCRIPT-006 | EsHandle separates raw host-handle identity from logical
resource ids and owner tokens, rejects duplicate identities, bounds table
accounting, and exposes transfer/close/release/failure/abandonment edges.
The focused IR fixture and check_handle_model.sh audit are static evidence;
platform descriptor acquisition and actual close calls remain host adapters.

ES-SCRIPT-007 | EsProcessSession binds validated ProcessCommand values to
clean pre-spawn state, distinct spawn handle identities, bounded stdout/stderr
aggregate accounting, bounded polls, typed terminal outcomes, and explicit timeout/cancellation
edges; a Created session must retain the SpawnFailure result sentinel until
Spawn, while post-spawn failure admits only host-I/O or output-limit outcomes.
The focused IR fixture and check_process_session.sh audit are static
evidence; fork/exec, signal escalation, and child reaping remain host work.

ES-SCRIPT-037 | EsProcessTermination supplies bounded process-group
termination/reaping ownership. It requires a nonzero owner, group, root, and
start-token identity for every member; records graceful request/ack, bounded
polls, force escalation, clean initial counters, monotonic reaped counts, cancellation intent,
timeout, and failure as explicit state-machine edges; and refuses `Reaped`
until every owned member is accounted for. The focused IR fixture, namespace
inclusion, documentation, and check_process_termination.sh audit are static
evidence; platform signal delivery, PID-generation lookup, wait/reap calls,
descendant races, and executed cleanup evidence remain host work.

ES-SCRIPT-008 | EsCliWorkflow maps every accepted launcher mode to a fixed
typed step sequence, validates mode-specific ordering and state/cursor
accounting, and exposes explicit step completion, failure, and cancellation
transitions. The focused IR
fixture and check_cli_workflow.sh audit are static evidence; host execution of
check/test/fmt/doc remains open.

ES-SCRIPT-011 | EsNetworkSession binds validated NetworkRequest policies to
ordered DNS/connect/TLS/send/receive phases, request/response byte accounting,
poll/redirect ceilings, an explicit bounded 3xx redirect reset edge,
state-consistent status outcomes, clean retry resets, and cancellation. The
focused IR fixture and check_network_session.sh audit are static evidence;
socket/TLS/redirect and deadline adapters remain open.

ES-SCRIPT-012 | EsRegex supplies typed operation identity, pattern/input/
replacement ceilings, capture-group limits, shared work accounting, bounded
replacement output, single/global match policy, and explicit
completion/failure/cancellation edges. The
focused IR fixture and check_regex_model.sh audit are static evidence; the
engine's iterative-stack rewrite and adversarial execution corpus remain open.

ES-SCRIPT-010 | EsEnvironment supplies bounded unique name/value entries,
sealed lookup, deterministic set updates, tombstone unsets, aggregate text
accounting, clean ready-state initialization, and explicit failure/reset
transitions without mutating parent
process state. The focused IR fixture and check_environment_model.sh audit are
static evidence; host environment snapshot/apply adapters remain open.

ES-SCRIPT-009 | EsCsvMaterialize supplies bounded source field spans, contiguous
record layout, quote markers, shared field/record ceilings, subtraction-safe record starts, clean ready-state
accounting, and validated slice lookup for CSV/TSV adapters. The focused IR fixture and
check_csv_materializer.sh audit are static evidence; quote unescaping,
newline policy, and typed row construction remain open.

ES-SCRIPT-013 | EsDifferentialStability supplies a bounded repeat session with
minimum/maximum repeat policy, baseline fingerprint accounting, stable-equal and
stable-mismatch classifications, and explicit nondeterminism rejection/reporting.
The focused differential fixture, namespace inclusion, documentation, and
check_differential_stability.sh audit are static evidence; scheduler-seed
control, host repeat execution, and fresh-environment qualification remain open.

ES-SCRIPT-014 | EsDifferentialFilesystem supplies bounded sealed post-run file
tree snapshots with strict path ordering, aggregate byte accounting, stable
fingerprints, and first-difference comparison for kind/content/size/mode and
executable metadata. The focused differential fixture, namespace inclusion,
documentation, and check_differential_filesystem.sh audit are static evidence;
filesystem enumeration/materialization and crash-safe restore remain host work.

ES-SCRIPT-015 | EsDifferentialOrder supplies a bounded dual-order execution
session, initial/final world fingerprints, duplicate-order rejection, and typed
order-independent, order-dependent, or world-contaminated classifications with
reject/report policy. The focused differential fixture, namespace inclusion,
documentation, and check_differential_order.sh audit are static evidence;
actual world reset and repeated host execution remain open.

ES-SCRIPT-016 | EsDifferentialTraceWindow supplies bounded pre/anchor/post
 lockstep records around a first divergence, strict step ordering, required
 anchor admission, position classification, and deterministic sealed-window
 fingerprints. The focused differential fixture, namespace inclusion,
 documentation, and check_differential_trace_window.sh audit are static
 evidence; adapter trace collection and execution evidence remain open.

ES-SCRIPT-017 | EsDifferential compares known in-process resource policy and
usage snapshots across steps, elapsed time, memory, open handles, processes,
output, regex work, retained traces, and concurrent tasks, while classifying
unknown external snapshots explicitly. The focused differential fixture,
documentation, and check_differential_resources.sh audit are static evidence;
host resource sampling and adverse-resource execution remain open.

ES-SCRIPT-018 | EsDifferentialEffectTrace supplies bounded ordered algebraic-
effect events with explicit family/operation identity, payload/result
fingerprints, resumption counts, multishot admission, sealed fingerprints, and
first-difference comparison with malformed-record rejection. The focused
differential fixture, namespace inclusion, documentation, and
check_differential_effect_trace.sh audit are static evidence; handler
instrumentation and execution evidence remain open.

ES-SCRIPT-019 | EsDifferentialReplay supplies a bounded replay lifecycle that
binds manifest/world fingerprints, enforces an explicit side order, requires
both run identities and a comparison before restoration, and rejects stale or
wrong-world completion. The focused differential fixture, namespace inclusion,
documentation, and check_differential_replay.sh audit are static evidence;
reproduction launch, host materialization, and crash recovery remain open.

ES-SCRIPT-020 | EsDifferentialRedaction supplies explicit exact-name/all-value
redaction policy, bounded environment capture, deterministic value fingerprints,
omission of selected secret values, duplicate-name/NUL/size rejection, and a
sealed capture lifecycle. The focused differential fixture, namespace
inclusion, documentation, and check_differential_redaction.sh audit are static
evidence; adapter field selection and secure storage remain open.

ES-SCRIPT-021 | EsDifferentialGenerator supplies a bounded deterministic
generator session with one recorded base seed, ordinal-derived case seeds,
ordered input fingerprints, and aggregate case/byte ceilings. The focused
differential fixture, namespace inclusion, documentation, and
check_differential_generator.sh audit are static evidence; schema-aware
generation, shrinking, and execution evidence remain open.

ES-SCRIPT-022 | EsDifferential shrink traces record bounded reduction ordinals,
candidate fingerprints, reduction kinds, preserved mismatch categories, and an
explicit exhausted-budget minimality proof. The focused differential fixture,
documentation, and check_differential_shrink_trace.sh audit are static
evidence; bounded aggregate-value slot reducers now preserve valid roots and
the original mismatch category; process termination/timeout reducers and
rerun-backed minimality remain open.

ES-SCRIPT-023 | EsRecordMaterialize supplies a bounded Perl/AWK-style record
materialization session with explicit begin-record/field/end-record/seal,
failure, and cancellation transitions. It validates every borrowed record and
field against EsRecord, enforces the record ceiling before `EndRecord` plus field/text ceilings, preserves ordered
field indices, checks contiguous record-to-field ownership, clears inactive
borrowed records/cursors after close or rollback, and rejects
post-terminal mutation through typed `error[RecordMaterializerError]`. The
focused IR fixture, namespace inclusion, documentation, and
check_record_materializer.sh audit are static evidence; byte-stream adapters,
regex scanning, external sort, and transactional rewrite execution remain open.

ES-SCRIPT-024 | EsRecordSort supplies a bounded external-sort ordering contract
with unique typed text/integer key positions, ascending/descending direction,
missing-key placement (with neutral missing payloads), stable ordinals, and subtraction-safe aggregate text
accounting. Its session admits ordered entries through explicit begin/record/
seal, failure, and cancellation transitions, and its pure comparator is shared
by in-memory and disk-merge adapters. The focused IR fixture, namespace
inclusion, documentation, and check_record_sort.sh audit are static evidence;
spill files, atomic publication, and merge I/O remain host work.

ES-SCRIPT-025 | EsRecordRewrite supplies a transactional in-place rewrite
contract for record/regex adapters. It requires distinct source/destination/
staging paths, optional non-colliding backups, a validated closed symlink policy, bounded
output and append counts, and the ordered `Begin → Append* → Sync →
DirectorySync? → Commit → CommitAck` lifecycle with failure, cancellation, and
rollback acknowledgements.
The focused IR fixture, namespace inclusion, documentation, and
check_record_rewrite.sh audit are static evidence; POSIX rename/fsync, mode and
permission preservation, crash recovery, and multi-file traversal remain host
work.

ES-SCRIPT-026 | EsRecordLifecycle supplies bounded begin/file/record/end hook
ordering with explicit early failure and cancellation. It validates file and
record ceilings before `RecordEnd`, rejects records outside an open file, prevents file closure
with an open record, tracks per-file emptiness policy, and clears ownership
state on terminal failure/cancel. The focused IR fixture, namespace inclusion,
documentation, and check_record_lifecycle.sh audit are static evidence; host
callback dispatch and multi-file traversal remain open.

ES-SCRIPT-027 | EsRecordAggregate supplies a bounded insertion-ordered keyed
counter for AWK/Perl-style associative aggregation. It enforces group/event/key
budgets, rejects duplicate internal groups and malformed keys, preserves first
ordinals, and now admits explicit bounded unsigned sums through `AddValue` with
sealed count/sum lookup. Planned sessions must start empty; sum overflow and
terminal mutation remain typed `error[RecordAggregateError]`. The focused IR fixture, namespace inclusion,
documentation, and check_record_aggregate.sh audit are static evidence; signed
numeric policies, joins, spill-to-disk aggregation, and host execution remain
open.

ES-SCRIPT-030 | EsRecordFields supplies a bounded field mutation and
reconstruction session for AWK `$N` and Perl-style record rewrites. It enforces
field/edit/output ceilings, explicit output separators and trailing-newline
policy, optional append-at-NF behavior, stable field positions, and
subtraction-safe reconstruction accounting. Missing edits clear a value to the
empty field rather than silently renumbering it; `Ready`-only joining and
post-terminal rejection are typed through `error[RecordFieldEditError]`. The
focused IR fixture, namespace inclusion, documentation, and
check_record_fields.sh audit are static evidence; scanner integration, typed
numeric conversion, and host execution remain open.

ES-SCRIPT-031 | EsRecordWindow supplies a bounded rolling unsigned-sum window
for streaming record actions. It retains at most `max_events`, exposes an
active suffix no wider than `width` (and rejects a nonempty history with an
empty active suffix), evicts the oldest value before each new
admission, and validates sum accounting against an explicit ceiling. Count and
sum reads are allowed only while collecting or after sealing; invalid lifecycle,
eviction, accounting, event, and sum transitions return
`error[RecordWindowError]`. The focused IR fixture, namespace inclusion,
documentation, and check_record_window.sh audit are static evidence; keyed
windows, signed/decimal values, and host execution remain open.

ES-SCRIPT-032 | EsRecordJoin supplies a deterministic bounded keyed-join
contract. Left/right rows retain side-local ordinals and borrowed key/value
views; row/key/value byte ceilings are checked before mutation; inner, left,
right, and full outer policies are explicit; duplicate keys produce bounded
Cartesian pair counts and unmatched outer rows contribute one pair each. The
sealed pair-count query and all invalid lifecycle, key, ordinal, accounting,
and pair-limit paths use `error[RecordJoinError]`. The focused IR fixture,
namespace inclusion, documentation, and check_record_join.sh audit are static
evidence; pair materialization, spill/merge adapters, and host execution remain
open.

ES-SCRIPT-033 | EsProcessBatch supplies a bounded fan-out/fan-in process-map
contract without launching children. It enforces unique job IDs, maximum jobs,
active parallelism, attempts before launch, pending/running/retryable/terminal states,
terminal-state accounting, planned cancellation, fail-fast versus aggregate
failure, and scoped `Cancel → CancelAck` cleanup.
The focused IR fixture, namespace inclusion, documentation, and
check_process_batch.sh audit are static evidence; scheduler ownership, actual
pipe/process adapters, signal escalation, and execution evidence remain open.

ES-SCRIPT-034 | EsRecordSpill supplies a bounded external-sort run contract.
Distinct staging/run/destination paths, stable run ordinals, per-run and
aggregate record/byte ceilings, explicit `SealRun → BeginMerge → MergeRun* →
Commit` ordering, ordered merge indices, Ready-to-Spilling re-entry, and failure/cancellation cleanup
edges are validated through `error[RecordSpillError]`. The focused IR fixture,
namespace inclusion, documentation, and check_record_spill.sh audit are static
evidence; sorting, fsync/rename, cleanup, crash recovery, and host execution
remain open.

ES-SCRIPT-038 | EsRecordNumeric supplies a bounded lexical numeric-field
contract for Perl/AWK-style extraction. Signed/unsigned integer magnitudes use
subtraction-safe overflow checks, decimal fields retain bounded coefficient/
fraction/exponent descriptors without an implicit float conversion, and sign,
underscore, decimal, exponent, finish, failure, and cancellation edges are
explicit under `error[RecordNumericError]`. The focused IR fixture, namespace
inclusion, documentation, and check_record_numeric.sh audit are static
evidence; exact-decimal/floating conversion, locale policy, and host scanner
integration remain open.

ES-SCRIPT-039 | EsRecordPattern supplies bounded pattern/action filtering and
inclusive-range selection for Perl/AWK-style record streams. Typed predicates,
explicit Select/Skip actions, host-supplied External observations, range-active
state, one decision per record, shape/record/text ceilings, and terminal
failure/cancellation edges are validated through `error[RecordPatternError]`.
The focused IR fixture, namespace inclusion, documentation, and
check_record_pattern.sh audit are static evidence; regex adapter integration,
callback dispatch, and executed stream parity remain open.

ES-FS-004 | EsFileLock supplies a bounded advisory file-lock ownership
contract. Requests carry explicit shared/exclusive mode, owner token, path and
bounded-wait policy; same-path shared leases may coexist, while exclusive and
same-owner re-entry conflicts are rejected. Acquisition attempts, retry,
timeout, cancellation acknowledgement, release acknowledgement, failed leases,
terminal lease-id exhaustion before publication, and active-lease accounting
are explicit state-machine edges under
`error[FileLockError]`. The focused IR fixture, namespace inclusion,
documentation, and check_file_lock.sh audit are static evidence; platform
flock/LockFileEx calls, fairness, mandatory-locking differences, and race
fixtures remain host work.

ES-FS-005 | EsDirectoryMutation supplies a bounded recursive copy/remove
planning contract. It records source/destination paths, stable identities,
depth and byte accounting, explicit applied/skipped/failed entry outcomes,
symlink preserve/follow/skip/reject policy, fail-fast versus collected partial
failures, balanced directory scopes, duplicate copy-destination rejection,
clean planned state, cycle/alias rejection, resource limits, and cancellation
through `error[DirectoryMutationError]`. The focused IR
fixture, namespace inclusion, documentation, and check_directory_mutation.sh
audit are static evidence; mkdir/copy/unlink/rmdir adapters, canonical path
containment, permissions, rollback, and race fixtures remain host work.

ES-FS-006 | EsWorkingDirectory supplies an exclusive per-invocation cwd
ownership contract for the unavoidable process-global chdir fallback. It
records the original/current/pending paths, owner token, bounded change count,
and explicit `Begin → Change → ChangeAck → Restore → RestoreAck` lifecycle;
concurrent owners, unacknowledged changes, and failed restore ownership are
rejected or retained as typed `error[WorkingDirectoryError]`; terminal lease-id
exhaustion is rejected before context publication so IDs cannot wrap to zero.
The focused IR fixture, namespace inclusion,
documentation, and check_working_directory.sh audit are static evidence;
descriptor-based adapters, platform cwd races, and executed failure/recovery
fixtures remain host work.

ES-SCRIPT-029 | EsRecordControl supplies explicit bounded `next`/`nextfile`/
exit transitions for pattern-action adapters. It closes record/file ownership
on skips, rejects record events outside files and premature file closure, caps
file/record counts before `RecordEnd` or `next` consumes another record, and clears scopes on
failure/cancel/exit. The focused IR
fixture, namespace inclusion, documentation, and check_record_control.sh audit
are static evidence; callback dispatch and multi-file host traversal remain
open.

ES-SCRIPT-028 | EsDifferentialTimeout supplies a bounded timeout/termination
shrink evidence session. It records reference/candidate side identity,
strictly decreasing timeout candidates, ordinal order, preserved mismatch kind,
nonzero rerun fingerprints, explicit accept/reject decisions, and exhausted
minimality proof without launching or signalling processes. The focused
differential fixture, documentation, and check_differential_timeout_shrink.sh
audit are static evidence; host process control and fresh-world reruns remain
open.
