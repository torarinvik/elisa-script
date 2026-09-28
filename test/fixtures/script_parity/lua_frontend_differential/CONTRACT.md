# Lua frontend differential-driver contract

This fixture binds W05 to the real developer-facing Python driver
`compiler/scripts/run_lua_frontend_differential.py` in the `Go projects/Elisa-core`
reference checkout. The currently observed root commit is
`a891c07857536c0f8b3c2ede3bf97385ba12f7c5`; the tracked driver blob remains
`0c520694c81537e333b8204ab110155ce2c6d133`. The driver source and tracked C
harnesses are inspected as source only; this contract has launched no Python,
Go, C, compiler, or benchmark process. A launcher must verify the root commit
and relevant tracked blobs before treating the checkout as the reference.

The expected frontend source and 27-case corpus are present in the current
checkout's ignored `Code/elisacore_lua/` directory, not in that commit's tree.
Their observed SHA-256 values are pinned in
`REFERENCE_INPUTS.sha256`. This detects content drift but does not establish
upstream history or authenticity; the launcher must require an exact manifest
match, a regular-file/no-symlink policy, and bounded corpus admission. A
missing path or any digest mismatch is an input-integrity failure, not an empty
corpus, and must stop before creating a compiler or C child. No fixture,
compiler, or parity execution has occurred.

## Public command surface

The reference uses Python `argparse` with these options:

```text
--corpus-root PATH       default: <repo>/Code/elisacore_lua/test/differential_corpus
--opt-level FLAG         default: -O3
--strict                 fail when any comparison or fingerprint mismatch exists
--keep-temp              retain the temporary build directory and print temp_root
--json-out PATH          write the machine-readable report
```

Options may be separated (`--corpus-root PATH`) or attached
(`--corpus-root=PATH`). Unambiguous long-option abbreviations are accepted by
the Python parser; ambiguous or unknown options, missing values, and a
post-`--` positional operand are status-2 usage failures. The replacement
must parse an argv vector, preserve spaces and empty values, and never pass a
constructed option string through a shell. It may use a stricter, explicitly
documented option spelling policy only if the fixture records the policy and
the status/message class is stable.

The source-only Elisascript seam `EsLuaFrontendArguments` now models this
boundary with typed usage errors, bounded raw arguments and paths, exact and
unambiguous abbreviated long options, attached/separated values, and explicit
flags distinguishing an absent path from a supplied empty path. Its runtime
test source is `test/runtime/lua_frontend_arguments_test.elisa`. This parser is
not yet connected to a launcher or the W05 workflow, and its tests have not
been compiled or run; it is implementation source, not parity evidence.

`EsLuaFrontendCorpus` now supplies the host-neutral index seam. Its inputs are
canonical absolute file paths, bounded source views, and injected regular-file
and symlink facts from a future `lstat` adapter. It validates containment under
the corpus root, `.lua` case prefixes, UTF-8 source, leading annotations,
family-required modes, duplicate paths, and Python `Path` component ordering
before producing any index. The current profile caps the index at 65,536
cases, 4,096 bytes per path, 16 MiB aggregate path text, 16 MiB per source,
and 64 MiB aggregate source text. The source test is
`test/runtime/lua_frontend_corpus_model_test.elisa`; neither model's runtime
tests have been compiled or run.

For annotation values, the Elisascript profile stores a sign and an
arbitrary-precision decimal digit vector, bounded by the already-enforced
source and corpus byte budgets. It accepts ASCII decimal digits with an
optional sign and Python-compatible single underscores between digits; leading
zeroes are normalized, and negative zero becomes zero. This avoids fixed-width
overflow while keeping the value strongly typed. Python `int()` also accepts
Unicode decimal digits; this model currently rejects those spellings as
`InvalidFingerprintInteger`, an explicit remaining parity gap. The pinned
27-case corpus uses ASCII values. Whitespace trimming and line splitting cover
Python's Unicode whitespace and `splitlines()` boundaries.

`EsLuaFrontendBuildPlan` now materializes the four exact argv vectors and
explicit working directories as typed `ProcessCommand` values. It requires
absolute bounded paths, checks the fixed source suffixes and output layout,
and supplies finite per-command deadlines and capture ceilings while
rejecting per-child RSS ceilings above 2 GiB. The process adapter must still enforce those ceilings and the
caller must keep the borrowed path storage alive. `PathFacts` and
`CompilerIdentity` preflight remain responsible for file identity, source
digests, symlink policy, temporary-root ownership, and approved executable
identity; the pure plan does not prove those host facts. Its source test is
`test/runtime/lua_frontend_build_plan_test.elisa` and remains uncompiled.

`EsLuaFrontendProcessReceipt` only classifies a normal exit after the host
confirms `exec` succeeded, the RSS guard was enforced, and the process group is
quiescent. A nonzero parser exit is then a rejection; build-role nonzero exits
and all abnormal or uncertain outcomes are infrastructure failures. This
distinction is necessary because the current POSIX interpreter path maps
`execvp` failure to ordinary exit 127 (and setup failure to 126), so that path
cannot yet provide trustworthy `ExecConfirmed` receipts. No RSS guard currently
feeds this model either. A process adapter must add explicit exec-status
reporting and real process-tree RSS enforcement before W05 may launch any
child. Test source is `test/runtime/lua_frontend_process_receipt_test.elisa`;
it remains uncompiled.

`EsLuaFrontendPinnedInputs` pins the exact SHA-256 of the tracked
`REFERENCE_INPUTS.sha256` lock and verifies its 28 exact source/corpus rows
against SHA-256 of the bytes supplied by preflight. It rejects missing,
duplicate, extra, or digest-mismatched inputs, reordered lock rows, symlinked,
non-regular, or oversized inputs before a build plan should be created.
`EsLuaFrontendPinnedInputsPosix` is the descriptor-relative host adapter: it
can open separate directory capabilities for this fixture and the Elisa-core
checkout by walking canonical absolute paths from `/` with `O_NOFOLLOW`, or
accept existing capabilities. It authenticates the bounded lock before
opening source rows and resolves every relative path component with
`O_NOFOLLOW`. It checks per-file and aggregate source limits before
allocating/reading each source, verifies the retained descriptor and its name
after the bounded read, then passes the exact arena-backed byte views to the
pure verifier. The path-based entry point owns and closes both root descriptors
on success and ordinary typed-error paths. The caller must keep the arena alive
through corpus admission and independently establish that the two selected
roots are the approved checkouts; safe path traversal alone does not establish
repository identity.
The adapter and pure source tests
(`test/runtime/lua_frontend_pinned_inputs_test.elisa` and
`test/runtime/lua_frontend_pinned_inputs_posix_test.elisa`) have not been
compiled or run; no runtime filesystem evidence is claimed.

The four process inputs are typed values, not a shell command:

```text
corpus_root: bounded absolute or workspace-relative path
opt_level: one validated compiler/clang flag from the supported profile
strict: boolean
keep_temp: boolean
json_out: optional bounded path
```

The replacement profile admits at most 4,096 bytes per path, 64 bytes for
`opt_level`, 65,536 corpus cases, 16 MiB aggregate path text, 16 MiB per
source, 64 MiB aggregate source text, 64 MiB retained report text, and 64 MiB
per captured child stream. It rejects embedded NULs and arithmetic overflow
before host conversion. A finite deadline, process-group ownership, RSS
ceiling, and output ceiling are mandatory launcher inputs; they are not
delegated to an unbounded Python `subprocess.run` call.

## Reference build graph and child argv

For every run the driver creates a private temporary root with `ll/` and
`ref/` subdirectories. The exact reference argv vectors are:

```text
go run ./src <opt> -emit header -o <ll>/lua_frontend.h <repo>/Code/elisacore_lua/src/lua_frontend.elisa
go run ./src <opt> -emit obj    -o <ll>/lua_frontend.o <repo>/Code/elisacore_lua/src/lua_frontend.elisa
clang <opt> -pthread -Wl,-undefined,dynamic_lookup -I <ll>
  <repo>/Code/benchmarks/lua_frontend_bench.c
  <repo>/Code/benchmarks/json_parser_runtime_shims.c
  <ll>/lua_frontend.o -o <ll>/lua_frontend_bench
clang <opt> -std=c99 <repo>/Code/benchmarks/lua_reference_parse_harness.c
  -lm -ldl -o <ref>/lua_reference_parse
```

The `go` and first `clang` children run with the pinned compiler checkout as
their working directory. The reference parser `clang` invocation currently
does not set a working directory; a replacement must set one explicitly to a
validated workspace root so relative tool resolution is deterministic. Each
child receives an argv vector and an inherited or explicitly pinned UTF-8
locale; no shell expansion, globbing, redirection, or environment mutation is
implicit.

Before any child is spawned, the launcher verifies every source/harness path,
the source pin, regular-file/no-symlink policy, and the bounded corpus graph.
It must also verify that the selected compiler identity is the approved local
identity for the run. A missing file, pin mismatch, tool-start failure,
timeout, output-limit breach, signal, or uncertain process-tree cleanup is a
typed infrastructure failure and is never converted into a parser rejection.

## Corpus and per-case behavior

`iter_cases` walks `*.lua` in `pathlib.Path` component-lexical order. A file must begin with
`accept_` or `reject_`; any other name is an input error. The parent directory
is the family. Leading comment lines may carry integer annotations of the form
`-- elisacore-<mode>-fp: <integer>`, where `<mode>` is `env`, `closure`,
`label`, or `analysis`. Accepted cases require these modes:

| Family | Acceptance mode | Fingerprint modes |
| --- | --- | --- |
| `control_flow`, `functions_closures`, `labels_gotos` | `checked` | `analysis`, plus family-specific `env`/`closure`/`label` |
| `numerics`, `operators`, `strings_comments`, `tables_calls`, `globals` | `parse` | `analysis`, plus `globals`: `env`, `closure` |

The reference candidate is invoked as `[bench, source, "1", mode]`; the C
parser is invoked as `[reference, source]`. A zero return code means accept;
any nonzero return code means reject for this comparison. For accepted cases,
fingerprints are read from the candidate's stdout using the first
`checksum=(-?[0-9]+)` match; a missing checksum is a typed driver error, not a
numeric mismatch. The replacement must preserve the exact source path in the
child argv and must not infer acceptance from stderr text.

Each result records:

```text
family, case, path
expected_accept, expected_status
elisacore_accept, elisacore_status
reference_accept, reference_status
ll_vs_ref_match, expectation_match, fingerprint_match
expected_fingerprints, elisacore_fingerprints, fingerprint_mismatches
```

The first difference is retained in lexical case order. A process failure,
timeout, crash, output-limit event, or malformed report is a distinct
infrastructure outcome and must not be represented as `reject`.

## Human and JSON output

For every case the human stream contains one line with `MATCH` or `MISMATCH`,
`FP_MATCH` or `FP_MISMATCH`, family, basename, expected status, candidate
status, reference status, and any expected/actual fingerprint values. The
summary line is exactly the stable field set:

```text
SUMMARY cases=N reference_mismatches=N expectation_mismatches=N fingerprint_mismatches=N corpus_root=PATH
```

With `--json-out`, the parent directory is created and the report is encoded
as UTF-8 JSON with `indent=2`, `sort_keys=True`, and exactly one final LF. Its
top-level keys are `tool`, `repo_root`, `corpus_root`, `opt_level`, `strict`,
`keep_temp`, `temp_root`, `elisacore_harness`, `reference_harness`, `summary`,
and `cases`. `summary` contains `cases`, the three mismatch counters, and
`strict_failed`. Paths are diagnostic metadata only; fixture comparison must
normalize the workspace root and must never require a machine-specific
absolute prefix.

The replacement must stage the report privately, enforce its byte ceiling,
flush/sync where supported, and publish atomically. A failed report write or
rename leaves an existing destination unchanged. `--keep-temp` is opt-in and
may retain only the run's private root; the default removes it after all
children are reaped. Cleanup failure is recorded separately from the parser
result.

Exit status is `0` unless `--strict` is set and any reference, expectation, or
fingerprint mismatch exists, in which case it is `1`. Usage, malformed corpus,
toolchain, resource, and cleanup failures use reserved nonzero infrastructure
classes and are never collapsed into strict mismatch status. The public
Elisascript launcher must expose these classes through `error[...]` rather than
returning an untyped integer alone.

## Deterministic seams and safety requirements

The candidate should separate pure functions from host effects:

- `DifferentialArguments` parses and validates argv.
- `CorpusCase`/`CorpusIndex` validates names, annotations, ordering, and limits.
- `BuildPlan` materializes the four typed child argv vectors and working dirs.
- `ProcessReceipt` records exit/signal/timeout/output-limit/cleanup facts.
- `CaseEvaluation` and `DifferentialReport` compare already-owned bounded data.
- `ClockFacts`, `CompilerIdentity`, and `PathFacts` are injected test seams.

The process adapter must capture stdout and stderr independently, admit bytes
before appending, poll a monotonic deadline, terminate the private process
group, reap every known child, and report uncertain descendants as unknown.
It must not use pipelines, temporary shell scripts, `shell=True`, or a direct
`go run` without the resource guard. The corpus preflight must bound total
file count, path bytes, and source bytes before a compiler or C process is
created; because the reference harness reads a file in one allocation, a
replacement must impose a hard per-source limit and reject a larger case
before invoking either side.

## Acceptance matrix

The eventual candidate and launcher fixtures must cover:

| Case | Required observation |
| --- | --- |
| Minimal accepted/rejected pair | Same status from candidate and C reference |
| Every family mode | Correct `parse`/`checked` selection and fingerprint mode set |
| Missing/invalid annotation | Stable input failure before child launch |
| Non-prefixed corpus file | Stable input failure, no partial report |
| Duplicate/lexically reordered paths | Deterministic first-difference order |
| Candidate/reference disagreement | Mismatch record and strict status 1 |
| Missing checksum | Infrastructure failure, not fingerprint `-1` success |
| Compiler/C child nonzero, signal, timeout | Typed process outcome with cleanup evidence |
| stdout/stderr over limit | Typed output-limit outcome without unbounded allocation |
| Missing source or pin mismatch | Fail closed before any compiler process |
| JSON report | Exact keys, sorted two-space bytes, one final LF |
| Existing report destination | Atomic replacement; failed staging preserves old bytes |
| `--keep-temp` and default cleanup | Explicit retention or complete owned-tree cleanup |

Execution, differential comparison, and adoption remain disabled while the
compiler validation hold is active. This contract is source-level evidence
for W05, not a claim that the Python driver, C reference, or Elisascript
replacement has run successfully.
