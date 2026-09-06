# Migration candidate manifest schema

`scripts/inventory_candidates.sh` emits a tab-separated, machine-readable
candidate manifest. It is a discovery artifact only: paths are never executed,
and `classify`/`classify-generated`/`retain-external` are provisional
dispositions until a maintainer reviews the record. The scanner refuses roots
with more than 200,000 regular files, emits mutually exclusive filename
patterns into a private temporary path list, and reads that list through an
explicit bounded state machine rather than a global de-duplication buffer;
split larger roots before generating a manifest.

`docs/migration-project-roots.tsv` is the checked-in partition manifest for the
declared project roots. `scripts/inventory_project_roots.sh` reads it and runs
both scanners once per root, adding `root_name` and `root_path` to every output
row. A malformed row, missing root, or per-root budget failure terminates the
coordinator; it never silently skips a declared project. Partitioning keeps
discovery within the measured resource envelope after a broad traversal proved
too expensive.

The first row is the exact header. Every later row has these fields:

| Field | Meaning |
|---|---|
| `path` | Absolute candidate path as discovered by `rg --files` |
| `kind` | `python`, `perl`, `awk`, `shell`, `makefile`, or `unknown` |
| `owner` | Maintainer identity; starts as `unassigned` |
| `review_status` | Manifest review state: `pending`, `reviewed`, or `blocked` |
| `entrypoint` | Direct executable, imported module, build recipe, CI hook, generated output, or `unknown` |
| `disposition` | `classify`, `classify-generated`, `retain-external`, `port`, `wrap-temporarily`, `archive`, or `remove-after-acceptance` |
| `risk` | `test`, `build`, `release`, or `unknown` discovery hint; replace with the reviewed risk class |
| `notes` | Provisional read-only note and later review evidence |

Generate a snapshot for the declared project roots without running any legacy
program:

```sh
scripts/inventory_candidates.sh \
  "/Users/torarinvikbjarko/Documents/Coding Projects" \
  > /tmp/elisascript-migration-candidates.tsv
```

The generated file should be stored outside the repository until ownership,
callers, inputs/outputs, permissions, environment, locale, platform, external
dependencies, semantics, fixtures, and acceptance evidence have been reviewed.
The inventory snapshot in `docs/migration-inventory.md` remains the source of
the declared roots and raw counts; this schema supplies the per-file record
shape needed before any deletion or migration claim.

Generate the partitioned combined stream outside the repository:

```sh
scripts/inventory_project_roots.sh \
  "/Users/torarinvikbjarko/Documents/Coding Projects" \
  "docs/migration-project-roots.tsv" \
  > /tmp/elisascript-migration-roots.tsv
```

The coordinator is read-only with respect to project roots; its only writes are
private temporary scanner outputs, removed on exit.

## Discovery signals

`scripts/inventory_signals.sh` emits a separate, read-only TSV with the fields
`path`, `signal`, and `detail`. It catches executable permission bits,
Python/Perl/AWK/shell-family shebangs, and inline `python -c`, `perl -e`, or
AWK command references. Signal rows are leads rather than dispositions: binary
executables, vendored code, generated output, and comments can all produce a
match and require maintainer review. The scanner never evaluates the matched
file or embedded command. To keep a broad root scan bounded, it skips `.git`,
`node_modules`, virtualenvs, Python caches, `vendor`, and `third_party`, refuses
roots with more than 200,000 regular files, and limits content inspection to
files no larger than 8 MiB. Traversal and content-search failures fail closed
instead of silently dropping a signal. Split larger roots and use the candidate
manifest when those trees themselves require review.

Regenerate the signal report outside the repository:

```sh
scripts/inventory_signals.sh \
  "/Users/torarinvikbjarko/Documents/Coding Projects" \
  > /tmp/elisascript-migration-signals.tsv
```
