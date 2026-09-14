# Migration candidate manifest schema

`scripts/inventory_candidates.sh` is the reference for
`scripts/inventory_candidates.elisascript`. Both emit a tab-separated,
machine-readable candidate manifest. It is a discovery artifact only: paths
are never read as program contents, parsed, imported, or executed, and
`classify`/`classify-generated`/`retain-external` are provisional dispositions
until a maintainer reviews the record.

The scanner resolves the requested root to a canonical absolute path (a
symlink used as the root is resolved), includes hidden entries, and does not
consult ignore files or ripgrep configuration. Root spelling follows the
Bash reference's default logical `cd` rule: normalize `..` before resolving
symlinks, then use the physical result. Relative roots use a valid inherited
`PWD` spelling when it names the actual working directory; otherwise they use
the physical working directory. In a quiescent tree, child symlinks are
excluded rather than traversed or emitted. The Bash reference
uses path-based `find`; the current Darwin Elisascript candidate uses
descriptor-relative traversal with no-follow lookups and opened-directory
identity checks. This narrows the child-symlink check/use race, but does not
contain hostile concurrent renames: both implementations require a quiescent,
non-hostile tree and are not security boundaries. It prunes exactly `.git`,
`node_modules`, `.venv`,
`__pycache__`, `vendor`, and `third_party`, wherever those names occur as
directory components. Matching is case-sensitive: `*.py`, `*.pl`, `*.pm`,
`*.awk`, `*.sh`, `*.bash`, `*.zsh`, `*.fish`, and exact `Makefile` or
`makefile` basenames. Candidate paths are globally sorted by unsigned
byte-lexicographic order. Spaces and UTF-8 names are retained; any path with a
tab, CR, or LF is rejected because those bytes cannot be represented
unambiguously in the TSV stream. Any traversal or resource failure exits before
the header is written.

Limits are 200,000 regular files, 200,000 traversed non-pruned directories,
64 traversed descendant directory levels (the root is depth zero), 262,144
descendant entries, 64 MiB aggregate descendant-path bytes, 40 MiB aggregate
candidate-path bytes, and 64 MiB final manifest bytes. A larger root must be
partitioned before inventory. Both implementations enforce entry, depth, and
path budgets while traversing rather than after collecting an unbounded census.
These logical limits are not a measured RSS ceiling: candidate classification
temporarily splits paths, and manifest records are rebuilt during preflight and
emission. A strict host-memory ceiling still requires profiling or a streaming
representation with explicit scratch accounting.
The shell reference streams a NUL-delimited `find` pipeline into its bounded path list;
the current Darwin Elisascript candidate uses descriptor-relative `openat` /
`fstatat` / `readdir` traversal and owned path arrays. It opens canonical-root
and child components one at a time with no-follow flags and compares opened
and named directory identity before descending. Excluded/pruned directories do
not count toward the depth cap. Descriptor-relative traversal cannot prevent a
hostile concurrent rename from moving an already-open directory outside its
lexical root, while the Bash reference remains path-based; neither is a sandbox
or a security boundary.

Ordinary traversal errors and the shared entry ceiling use the canonical-root
diagnostic. Exceeding the 64-level bound uses
`inventory_candidates: directory depth exceeds limit (64) for <root>\n`.

The source-level process-parity fixture covers an explicit canonical root,
logical symlink/`..` root normalization, relative roots with a valid or stale
`PWD`, and omitted-root launches through symlinked script paths. The Bash
reference derives its omitted-root default from its own script location; the
Elisascript `main` derives it from `Script::source_path()`. These cases remain
unqualified until the public-launcher matrix is run after explicit validation
reauthorization; source fixtures alone are not evidence of parity.

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
file or embedded command. This shell implementation remains the reference for
the separate signal-discovery task. The native Elisascript candidate currently
covers `inventory_candidates.sh`; a source-only
`scripts/inventory_signals.elisascript` draft now covers signal orchestration.
It invokes `find`, `rg`, and `sort` through typed argv process capture, with no
shell or Python intermediary. Keeping ripgrep as a declared dependency retains
its inherited ignore/config/binary policy; the draft is not yet evidence of
signal parity or adoption.

The signal reference excludes `.git`, `node_modules`, `.venv`, `__pycache__`,
`vendor`, and `third_party` from its `find` traversal and refuses a root reported
to contain more than 200,000 regular files. A root whose own physical basename
is one of those excluded names produces only the header. Both implementations
first apply Bash-logical `cd` normalization and then resolve the selected root
physically once; output paths are absolute physical paths even when the input is
relative or a symlink to a directory. This follows an explicit root symlink,
but does not follow descendant symlinks. Relative roots beginning with `-` are
therefore passed to host tools only as absolute paths. A tab, CR, or LF in
either the supplied or resolved root is rejected before traversal.
Executable discovery uses
`find -type f -perm -111`: this requires all three user/group/other execute
permission bits, not merely any one execute bit. Child symlinks are not
followed. The two content searches use ripgrep with `--hidden`,
`--no-messages`, an 8 MiB maximum file size, and the same named-directory
exclusions. Unlike the `find` scan, ripgrep retains its normal ignore behavior
and binary-file policy, and it inherits ripgrep configuration and environment
settings other than the reference's `LC_ALL=C`. A search status of 1 means no
matches and is successful; other nonzero search statuses are errors. Rows from
the executable, shebang, and inline-command categories are combined and sorted
uniquely under the C locale.

After resolving and validating the selected root, both implementations preflight
the presence of `find`, `rg`, and `sort`, except that an excluded root returns
its header before tool lookup. A missing required tool produces status 127, no
stdout, and the stable diagnostic
`inventory_signals: required tool not found: NAME`. The shell uses `command -v`;
the Elisascript draft checks PATH entries for regular executable files. This is
an availability check, not a reservation: a tool can still disappear or be
replaced before process creation, so tool-spawn failures remain a separate
runtime failure case.

The shell reference's line-oriented path lists and TSV output cannot represent
tabs or line breaks in paths unambiguously, and it has no explicit final-output
byte ceiling. Its initial `find | wc -l | tr` count also does not preserve the
first `find` status; a later executable traversal checks its own status, but
does not prove the earlier count was complete if the filesystem changes between
walks. An Elisascript port must either match these limitations or define and
fixture deliberate fail-closed improvements. In particular, replacing
ripgrep's ignore/config/binary behavior with a custom regex walk is not a
semantics-preserving implementation. File-count, per-file-size, process-output,
and final-manifest limits should be specified together before adoption. Split
larger roots and use the candidate manifest when those trees themselves require
review.

The current Elisascript draft uses NUL-delimited `find`/`rg` output internally,
rejects tab/CR/LF paths before producing TSV, caps scanned regular-file path
bytes at 60 MiB, accounts a conservative 64 MiB header-plus-row ceiling while
building pre-sort/pre-dedup rows, and fails closed on a nonzero `find` or sort
status. These are intentional safety-policy differences from the shell
reference: the post-capture resource ceilings and fail-closed handling of
descendant paths with TSV delimiters still need matching shell limits or
explicit candidate-only contracts and boundary fixtures before exact parity can
be claimed. The runtime also caps each
captured process stream at 64 MiB and applies its process deadline; those host
guards do not establish a measured peak-RSS bound. The file-count/path/output
checks occur after process capture and byte-wise NUL scanning, so they are
logical admission limits rather than pre-capture memory guards. The candidate
retains row strings, joins them for sorting, and captures sorted output, so
peak workspace is not equal to the manifest cap. The 200,000-file ceiling also
does not bound a tree containing arbitrarily many empty directories; the
process deadline is the only current traversal-work bound.
Default-root construction lexically absolutizes the source directory and
normalizes `../..` before the shared physical-root resolution, matching the
shell's logical `cd` followed by physical `pwd -P` behavior. Explicit symlink
roots, dash-leading relative roots, excluded roots, Bash-logical
`symlink/..` normalization, and omitted-root/default-root behavior now have a
source-only fixture defining process-parity cases at
`test/script_parity/inventory_signals_launcher_test.elisascript`. It also
covers the six partial execute-bit combinations, hidden and ignored files,
excluded child directories, an outside-root symlink, TSV-delimiter rejection,
and a marker proving discoveries are not executed. A NUL-containing file and
an over-8-MiB file both contain otherwise-matching shebangs, exercising
ripgrep's binary and size policies. The fixture is uncompiled and unrun;
symlinked candidate-launch-path behavior, tool-spawn failures, and larger
resource-boundary behavior remain uncovered. Private
`find` and `rg` shims define executable-traversal and first-search failures; a
deterministic `sort` shim defines the nonzero-exit stdout/stderr/status
comparison. The candidate forwards sort's streams and status after printing
the reference's header. All these process fixtures are uncompiled and unrun.
Root resolution and subsequent process traversals are separate filesystem
operations, so concurrent root replacement remains a time-of-check/time-of-use
risk; parity is intended for quiescent trees. The
draft and fixture do not establish public-launcher parity, platform/tool
equivalence, resource behavior, or exact row equality.

Regenerate the signal report outside the repository:

```sh
scripts/inventory_signals.sh \
  "/Users/torarinvikbjarko/Documents/Coding Projects" \
  > /tmp/elisascript-migration-signals.tsv
```
