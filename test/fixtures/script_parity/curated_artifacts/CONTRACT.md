# Curated-artifact manifest validator: shell/AWK port

Real reference: `../neural-computer-agentV2/scripts/verify_curated_artifacts.sh`.
The unchanged `reference.sh` snapshot has SHA-256
`059ede426e6342465555d4c8550a249698bff6082a01b6a2a9b00409f6d8e6c2`.
Candidate: `scripts/check_neural_curated_artifacts.elisascript`, with pure
state-machine validation in `src/runtime/checksum_manifest_model.elisa`.
Neither the original nor its callers have been modified.

The candidate lives in elisa-script and selects the neighboring
`neural-computer-agentV2` root from its resolved source directory. Its public
`EsCuratedArtifactCheck::run_root(Path)` permits isolated fixture roots.
Public-launcher fixtures must copy the candidate and its runtime include
closure under `elisa-script/` beside a temporary `neural-computer-agentV2/`,
put the reference at the latter's `scripts/verify_curated_artifacts.sh`, and
create only known fixture artifact/manifest files. Do not point a parity run at
live curated checkpoints or another agent's training/SSH workspace.

## Ordinary stable-input contract

Enter the project root first. If metadata says the manifest is missing/empty,
or metadata lookup fails (Bash's false `-s` predicate), print exactly
`No curated checkpoints are currently registered.` plus newline and exit 0.
Extra wrapper arguments are ignored.

For a nonempty readable UTF-8 manifest within bounds, LF delimits records.
Spaces and tabs collapse as field separators; leading/trailing runs produce no
empty fields. CR, VT, FF and Unicode whitespace are not silently stripped.
This follows the standard default-field rule described in the
[GNU AWK field documentation](https://www.gnu.org/s/gawk/manual/html_node/Fields.html),
not a general Unicode-whitespace split or Python universal-newline iterator.
The installed reference AWK and locale still require fixture qualification.

A record is valid only if it has exactly two fields and the first is exactly
64 ASCII hex digits, accepting both cases. Filename tokens are opaque here;
the validator is not a path sanitizer or checksum-format rewriter. Blank
records, one/three-field records, short/long hashes, and nonhex hash bytes each
yield one diagnostic, even when several predicates fail on the same record:
`invalid checksum manifest line <NR>` plus newline on stderr. Report all bad
records in input order and return 1, without launching the hash tool. A final
unterminated record counts; a final LF does not invent an extra record.

If validation succeeds, invoke `shasum` through inherited PATH with exactly
`-a`, `256`, `-c`, `artifacts/manifests/curated_checkpoints.sha256`. Inherit all
three streams and the environment, disable the default deadline, and return
ordinary tool exit status without added output. The original manifest is passed
unchanged: binary markers, filename spelling and checksum-tool parsing remain
the selected shasum tool's responsibility. No shell, AWK, Python automation
script, or original wrapper is launched by the candidate. Shasum is retained
as a purpose-built SHA-256 tool, not a hidden validator implementation.

## Authored model fixtures; required launcher cases

`test/runtime/checksum_manifest_model_test.elisa` has source-only fixtures for
empty/valid records, case-insensitive hex, leading/trailing/repeated separators,
ordered multi-defect lines, upper hash-length/nonhex failures, final LF/partial
records, CR/VT/FF/nonbreaking-space distinctions, and the 4,096-issue boundary.
These tests have not compiled or run. They do not prove the checksum tool ran,
was skipped, or received the right argv.

Future gated public-launcher cases must independently assert:

- Missing, zero-byte, ordinary symlinked and dangling-symlink manifests.
- Valid final partial records; blank/whitespace-only lines; valid/invalid mixtures
  and every shape predicate, with exact stderr ordering and no tool launch.
- Correct artifact hash, mismatch, missing artifact, binary marker, filename
  tokens with punctuation, duplicate entries, and relevant shasum diagnostics.
- Probe-backed hash-tool argv/cwd/environment/status and binary streams; invalid
  validation must start no probe. Do not derive expected validation with this
  candidate or simply accept reference/candidate agreement.
- Cwd failure before any manifest handling; caller cwd/project paths with spaces.
- Input/record/issue bounds, unreadable/nonregular files, invalid UTF-8, changing
  files, locale/AWK-version differences, and hash-tool spawn/signal failures.

Use bounded captures, process-tree time/RSS containment, explicit opt-in, pinned
local compiler/launcher/reference/AWK/hash-tool identities, independent expected
observations and recorded-path cleanup. A checksum manifest can name absolute,
parent-relative or symlinked files: safe fixtures must use only isolated known
paths. The source script does not provide containment for untrusted manifests.
If hashing is delegated to the native process probe, use its full binary-frame
capture budget and separately qualified, pinned prebuilt binary.

## Open differences and safety boundaries

The candidate admits at most 4 MiB of manifest text, 65,536 records and 4,096
issues. Its descriptor reader verifies stable regular-file identity and strict
UTF-8. Bound/read/nonregular/encoding failures use candidate-specific diagnostics
and status 2 rather than reproducing AWK's host errors. No partial shape
diagnostics are printed after a model-budget error. These are explicit bounded
differences, not accepted reference parity on arbitrary inputs. Parsing bounds
do not bound artifact sizes read by the external streaming hash tool or provide
a hard RSS cap. The reader currently uses the Darwin adapter.

Validation and shasum are separate passes over the named manifest, as in the
reference; snapshot identity is not sealed across the external hash operation.
Concurrent replacement between those passes remains unqualified. Bash logical
PWD/symlink spelling, the runner's fork/wait versus exec/job-control behavior,
tool-spawn diagnostics and 126/127 policies also remain open.

This is a source-only candidate and contract, not a passing replacement.
Compiler, AWK/reference/candidate audits, checksum tools and parity execution
remain disabled until explicitly reauthorized. Keep the original until both
validation and real checksum-tool workflow parity have been observed safely.
