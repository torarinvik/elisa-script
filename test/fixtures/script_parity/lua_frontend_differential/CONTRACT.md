# Lua frontend differential-driver contract

This fixture binds W05 to the real developer-facing Python driver
`compiler/scripts/run_lua_frontend_differential.py` in the pinned reference
checkout. The source pin currently observed in `Go projects/effect-worktree/`
is commit `5284109ca5805560a488c3b0a5d8cd4a1a45e317`, blob
`0c520694c81537e333b8204ab110155ce2c6d133`. The driver source, its C harnesses,
and the corpus are inspected as source only; this contract has launched no
Python, Go, C, compiler, or benchmark process. A launcher must verify the
commit and blob before treating the checkout as the reference.

The current pinned checkout does not contain the driver's expected
`Code/elisacore_lua/src/lua_frontend.elisa` path. That is an input-integrity
failure, not an empty corpus: the replacement must report the missing source
root and stop before creating a compiler or C child. The pin and path check are
therefore part of the acceptance boundary, and this fixture must not be marked
executed until a checkout containing the pinned workflow is supplied.

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

The four process inputs are typed values, not a shell command:

```text
corpus_root: bounded absolute or workspace-relative path
opt_level: one validated compiler/clang flag from the supported profile
strict: boolean
keep_temp: boolean
json_out: optional bounded path
```

The initial replacement profile admits at most 4,096 bytes per path, 64 bytes
for `opt_level`, one million corpus cases, 64 MiB of retained report text, and
64 MiB per captured child stream. It rejects embedded NULs and arithmetic
overflow before host conversion. A finite deadline, process-group ownership,
RSS ceiling, and output ceiling are mandatory launcher inputs; they are not
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

`iter_cases` walks `*.lua` in lexical path order. A file must begin with
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
