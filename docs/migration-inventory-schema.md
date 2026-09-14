# Migration candidate manifest schema

`scripts/inventory_candidates.sh` is the reference for
`scripts/inventory_candidates.elisascript`. Both emit a tab-separated,
machine-readable candidate manifest. It is a discovery artifact only: paths
are never read as program contents, parsed, imported, or executed, and
`classify`/`classify-generated`/`retain-external` are provisional dispositions
until a maintainer reviews the record.

The scanner resolves the requested root to a canonical absolute path (a
symlink used as the root is resolved), includes hidden entries, and does not
consult ignore files or ripgrep configuration. In a quiescent tree, child
symlinks are excluded rather than traversed or emitted. The current path-based
check/use sequence is not race-safe against concurrent filesystem mutation, so
this is not a security boundary for hostile or actively changing trees. It
prunes exactly `.git`, `node_modules`, `.venv`,
`__pycache__`, `vendor`, and `third_party`, wherever those names occur as
directory components. Matching is case-sensitive: `*.py`, `*.pl`, `*.pm`,
`*.awk`, `*.sh`, `*.bash`, `*.zsh`, `*.fish`, and exact `Makefile` or
`makefile` basenames. Candidate paths are globally sorted by unsigned
byte-lexicographic order. Spaces and UTF-8 names are retained; any path with a
tab, CR, or LF is rejected because those bytes cannot be represented
unambiguously in the TSV stream. Any traversal or resource failure exits before
the header is written.

Limits are 200,000 regular files, 200,000 traversed non-pruned directories,
262,144 descendant entries, 64 MiB aggregate descendant-path bytes, 40 MiB
aggregate candidate-path bytes, and 64 MiB final manifest bytes. A larger root
must be partitioned before inventory. `Path.iterdir()` also applies its
per-directory adapter bound; the shared global entry limit is no larger than
that ceiling. Both implementations enforce entry and path budgets while
traversing rather than after collecting an unbounded census. The shell
reference streams a NUL-delimited `find` pipeline into its bounded path list;
the Elisascript port uses native directory traversal and owned path arrays.
Failures from either a traversal error or the shared entry ceiling use the same
canonical-root diagnostic; the native directory adapter does not expose whether
its own per-directory ceiling or a filesystem error caused the failure.

The process-parity fixture always supplies an explicit root. The Bash reference
derives its omitted-root default from its own script location, while the current
Elisascript `main` uses `..` relative to the process working directory; those
defaults are not yet claimed equivalent when launched from an arbitrary working
directory. Default-root parity remains open until the launcher exposes a stable
script-relative path or both tools adopt an explicit shared default contract.

`docs/migration-project-roots.tsv` is the checked-in partition manifest for the
declared project roots. `scripts/check_migration_roots.sh` validates its shape,
ownership, and directory boundaries before `scripts/inventory_project_roots.sh`
reads it and runs
both scanners once per root, adding `root_name` and `root_path` to every output
row. A malformed row, missing root, or per-root budget failure terminates the
coordinator; it never silently skips a declared project. Partitioning keeps
discovery within the measured resource envelope after a broad traversal proved
too expensive.
Both tools canonicalize the configured root and every declared directory with
`pwd -P`, reject a symlink-resolved path that escapes the coding-projects tree,
and pass only the canonical in-tree path to scanners. Report metadata retains
the declared manifest path for review. The coordinator repeats the manifest
shape, ownership-state, duplicate-name, and duplicate-path preflight itself so
direct invocation cannot bypass the fail-closed audit.

The candidate scanner recognizes a `Makefile` or `makefile` directly at the
scan root (not only when it has a parent directory). The separate signal
scanner continues to use its own documented discovery policy.

The candidate scanner's first row is the exact seven-column header below. Every
later row has the same fields and order:

```
path	kind	owner	entrypoint	disposition	risk	notes
```

| Field | Meaning |
|---|---|
| `path` | Canonical absolute candidate path |
| `kind` | `python`, `perl`, `awk`, `shell`, or `makefile` |
| `owner` | Maintainer identity; starts as `unassigned` |
| `entrypoint` | Direct executable, imported module, build recipe, CI hook, generated output, or `unknown` |
| `disposition` | `classify`, `classify-generated`, `retain-external`, `port`, `wrap-temporarily`, `archive`, or `remove-after-acceptance` |
| `risk` | `test`, `build`, `release`, or `unknown` discovery hint; replace with the reviewed risk class |
| `notes` | Provisional read-only note and later review evidence |

The partition coordinator prepends `root_name` and `root_path` and emits a
nine-column stream:

```
root_name	root_path	path	kind	owner	entrypoint	disposition	risk	notes
```

The `review_status` field belongs to the checked-in root manifest and to the
maintainer-reviewed file manifest (`docs/migration-review-current.tsv`); it is
not silently fabricated by the candidate scanner. The reviewed manifest has
its own eight-column header:

```
path	kind	owner	review_status	entrypoint	disposition	risk	notes
```

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
