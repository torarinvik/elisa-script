# Bounded Elisascript repository inventory

This is a read-only discovery snapshot for the current Elisascript repository.
It is evidence for the migration workflow, not a claim that any legacy file has
been ported or may be deleted.

Snapshot date: 2026-09-06  
Scan root: `/Users/torarinvikbjarko/Documents/Coding Projects/Elisa Projects/elisa-script`  
Commands: `scripts/inventory_candidates.sh "$PWD"` and
`scripts/inventory_signals.sh "$PWD"`  
Reports: `/tmp/elisascript-migration-candidates-current.tsv` and
`/tmp/elisascript-migration-signals-current.tsv`

No candidate or embedded command was sourced, parsed as a program, or executed.
The scan completed within the repository-local resource envelope. A prior scan
of the entire `Elisa Projects` tree was stopped after `find` reached roughly
460 MiB RSS; broad roots must be partitioned before another inventory attempt.

## Discovery counts

| Artifact | Count |
|---|---:|
| Shell-family filename candidates | 10 |
| Executable-file signals | 8 |
| Legacy-shebang signals | 9 |
| Inline Python/Perl/AWK signals | 7 |

The nine shell candidates are all repository maintenance tools under `scripts/`:
inventory generators, compiler-validation wrappers, and compiler-free audits.
They are migration candidates for the eventual P15 dogfooding wave, but the
validation wrappers remain safety controls and must not be replaced or enabled
until the validation gate is explicitly reauthorized.

## Representative acceptance cases

These are the first bounded workflows to use when an Elisascript replacement is
designed. They are deliberately classified by behavior rather than filename:

| Workflow | Current artifact | Required replacement contract |
|---|---|---|
| Static source audit | `scripts/check_namespace_manifest.sh` | walk modules/includes, enforce public/private namespace rules, fail with deterministic diagnostics, no compiler launch |
| Typed-surface audit | `scripts/check_builtin_surface.sh` | compare one typed builtin registry against semantic/lowering consumers, preserve nonzero failure status and report missing entries |
| Snapshot-field audit | `scripts/check_diagnostic_snapshot.sh` | parse source declarations, verify every host-visible diagnostic field is covered, reject omissions deterministically |
| Migration discovery | `scripts/inventory_candidates.sh` and `scripts/inventory_signals.sh` | bounded filesystem traversal, TSV output, no sourcing/execution, explicit resource failure |
| Validation safety control | `scripts/run_bounded_lowering.sh`, `scripts/run_bounded_test.sh`, and `scripts/stop_bounded_validation.sh` | preserve fail-closed leases, emergency stop, exact process ownership, and disabled-by-default compiler execution |

The first three audits are pure, deterministic, and suitable for an early
Elisascript port once module/file/regex/process-free text facilities are stable.
The inventory tools require streaming directory traversal and bounded text
matching. The validation controls are later migration targets and must retain
their safety semantics even while compiler execution remains disabled.

## Open inventory work

- The checked-in partition manifest `docs/migration-project-roots.tsv` and
  `scripts/inventory_project_roots.sh` now scan each declared project root
  independently with bounded, read-only candidate and signal scanners. Missing,
  malformed, or unlisted roots fail closed; the coordinator writes only to a
  private temporary directory and removes it on exit. Both scanners also fail
  closed on traversal or search errors, and `scripts/check_migration_inventory.sh`
  audits the manifest/coordinator boundary without launching a compiler.
  `scripts/check_migration_roots.sh` separately validates root ownership and
  declared directory existence before a coordinator scan is authorized.
- Review every emitted record for owner, callers, inputs/outputs, external
  dependencies, platform behavior, fixtures, and acceptance evidence.
- Add owner, callers, inputs/outputs, external dependencies, platform behavior,
  fixtures, and acceptance evidence to every candidate record.
- Keep generated/vendored files and safety wrappers explicitly classified before
  any port or removal decision.

The current repository candidates (now ten shell-family files) have now received that review in
`docs/migration-review-current.tsv`. The reviewed manifest assigns the
`elisascript-maintainers` owner role, records callers and I/O/dependency/platform
notes, and classifies all four validation safety wrappers as
`retain-external`. `scripts/check_migration_review.sh` audits that every current
candidate is present exactly once, reviewed, non-placeholder-owned, and carries
an approved `port` or `retain-external` disposition without executing any row.
