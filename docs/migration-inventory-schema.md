# Migration candidate manifest schema

`scripts/inventory_candidates.sh` emits a tab-separated, machine-readable
candidate manifest. It is a discovery artifact only: paths are never executed,
and `classify`/`classify-generated`/`retain-external` are provisional
dispositions until a maintainer reviews the record.

The first row is the exact header. Every later row has these fields:

| Field | Meaning |
|---|---|
| `path` | Absolute candidate path as discovered by `rg --files` |
| `kind` | `python`, `perl`, `awk`, `shell`, `makefile`, or `unknown` |
| `owner` | Maintainer identity; starts as `unassigned` |
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

## Discovery signals

`scripts/inventory_signals.sh` emits a separate, read-only TSV with the fields
`path`, `signal`, and `detail`. It catches executable permission bits,
Python/Perl/AWK/shell-family shebangs, and inline `python -c`, `perl -e`, or
AWK command references. Signal rows are leads rather than dispositions: binary
executables, vendored code, generated output, and comments can all produce a
match and require maintainer review. The scanner never evaluates the matched
file or embedded command. To keep a broad root scan bounded, it skips `.git`,
`node_modules`, virtualenvs, Python caches, `vendor`, and `third_party`; use the
candidate manifest or a narrow explicit root when those trees themselves
require review.

Regenerate the signal report outside the repository:

```sh
scripts/inventory_signals.sh \
  "/Users/torarinvikbjarko/Documents/Coding Projects" \
  > /tmp/elisascript-migration-signals.tsv
```
