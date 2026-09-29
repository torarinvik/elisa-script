# Real-project source-length gate

Reference: `../wasmbrowser-proof/scripts/check_source_length.py`. The unchanged
snapshot in `reference.py` has SHA-256
`d6d5a5c8d1dc2897fe176b87d2e1a3de9d2592337ae092283c986ad7748ab052`.
Candidate: `scripts/check_wasmbrowser_source_length.elisascript`, with a pure
counter in `src/runtime/source_length_model.elisa` and authored regression
tests in `test/runtime/source_length_model_test.elisa`. Component-wise ordering
fixtures are in `test/script_parity/source_length_order_test.elisascript`.

The candidate lives in elisa-script and selects its neighboring
`wasmbrowser-proof` project using its own resolved source directory. It is not
installed in that project, and neither the original Python script nor its
`scripts/test.sh` caller has changed. A future public-launcher fixture must
copy these siblings under one temporary workspace:

```text
workspace/
  elisa-script/
    scripts/check_wasmbrowser_source_length.elisascript
    src/runtime/source_length_model.elisa
    src/runtime/bounded_text_posix.elisa
    src/runtime/encoding.elisa
    src/runtime/file_posix.elisa
    src/runtime/directory_posix.elisa
    src/runtime/stdio_posix.elisa
  wasmbrowser-proof/
    scripts/check_source_length.py
    src/...
```

`EsProofSourceLength::run_root(Path)` also exposes the operation without tying
the implementation to the default neighboring-project layout. Deployment as a
standalone companion will require bundling the reader/include closure and
changing the default root selection, not an unqualified copy of this file.

## Exact ordinary-tree contract

For a stable, readable tree within the limits below, compare status and exact
stdout/stderr bytes. Empty/missing/non-directory `src` and all files with at
most 600 lines produce status 0 and no output. More than 600 lines produces
status 1, no stdout, and one stderr line for every oversized file:

```text
source file exceeds 600 lines: src/<relative-name> (<line-count>)
```

The suffix is case-sensitive `.elisa`. Hidden files and directories are
included. File symlinks are followed by the reader; descendant directory
symlinks are not traversed. A symlink used as the initial `src` root is allowed.
Matching directories and broken symlinks are not silently filtered out: they
reach the read-error path, like pathlib's rglob results.

Count Python UTF-8 text-file iteration lines, with universal CRLF, LF, and CR
newlines. An empty file has zero lines; a final unterminated segment has one.
CRLF is one newline, even in mixed input. Unicode NEL/U+2028/U+2029, vertical
tab, form feed, and NUL are ordinary content. A UTF-8 BOM is content as with
`encoding="utf-8"`, not `utf-8-sig`. This is deliberately not `splitlines()`.

Diagnostics use pathlib's component-wise sort order. In particular,
`src/a/z.elisa` precedes `src/a.elisa`, despite plain full-path byte sorting
putting them the other way around. Separator-to-NUL keys encode that order for
valid UTF-8 POSIX filenames. Size diagnostics are withheld until every source
read succeeds, matching the reference's collection-before-printing structure.
Extra command-line arguments are ignored by both scripts.

## Required public-launcher matrix (not yet implemented or executed)

- Empty and missing src; a regular file named src; no matching source files.
- Empty file, 599/600/601 lines, and final lines with/without a terminator.
- LF, CRLF, bare CR, repeated CR, mixed terminators, and Unicode separators.
- Several oversized sources, including `a.elisa`, `a/z.elisa`,
  `a-/z.elisa`, `.hidden.elisa`, `.hidden/child.elisa`, and Unicode filenames.
- Caller cwd unrelated to the fixture, and a workspace path containing spaces.
- File symlink inside/outside src; descendant directory symlink and symlink
  cycle (not followed); source root symlink; matching directory `.elisa`.
- An earlier oversized file followed by unreadable/invalid UTF-8 input:
  no partial oversized-file diagnostics may escape.
- File and aggregate byte limits, directory/entry/depth/path limits, and a file
  changing during read. Keep resource-limit failures separate from parity.

Pin the reference, candidate, include closure, qualified launcher, and local
compiler identities. Use the existing explicit opt-in and bounded RSS guard,
per-process deadlines, bounded captures, independent observations of both
programs, and deterministic cleanup of only the isolated fixture. Do not run
against or mutate the live proof-assistant repository during fixture tests.
Success/error fixtures must assert expectations, not just agreement between
two possibly broken implementations.

## Bounded behavior and open gaps

The candidate reads at most 16 MiB per file and 64 MiB in aggregate, processing
one source at a time. This is not a guarantee that interpreter-owned arenas
release a prior source immediately. Discovery permits 8,192 matching paths, 4,096 directories,
depth 64 below src, 16,384 entries per directory, 65,536 total entries, paths
shorter than 4,096 bytes, and 16 MiB of enumerated path bytes. Path.iterdir's own
runtime materialization bound applies before the per-directory check. These
logical budgets are not a hard process RSS guarantee.

Unreadable, changing, non-regular, invalid UTF-8, and over-limit inputs produce
a candidate-specific diagnostic and status 2, not Python's traceback/status 1.
Directory-enumeration errors are fail-closed rather than relying on pathlib's
version-dependent suppression. Filesystem races, invalid-UTF-8 filenames, and
platform-specific pathlib collation are outside current exact acceptance.
The bounded reader currently uses the Darwin POSIX adapter, not a proven
cross-platform implementation. No resource ceiling or error divergence may be
called exact Python parity.

This records source work, not runtime evidence. The pure-counter tests and
public-launcher matrix have not run. Compiler, audit, and parity execution
remain disabled until explicitly reauthorized; the original stays authoritative.
