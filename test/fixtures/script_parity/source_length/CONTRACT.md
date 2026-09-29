# Real-project source-length gate

Reference: `../wasmbrowser-proof/scripts/check_source_length.py`. The unchanged
snapshot in `reference.py` has SHA-256
`d6d5a5c8d1dc2897fe176b87d2e1a3de9d2592337ae092283c986ad7748ab052`.
The public launcher checks that the live neighboring reference has this exact
hash both before and after its matrix, so local fixture drift cannot silently
turn the test into parity against a stale Python snapshot.
Candidate: `scripts/check_wasmbrowser_source_length.elisascript`, with a pure
counter in `src/runtime/source_length_model.elisa` and authored regression
tests in `test/runtime/source_length_model_test.elisa`. Component-wise ordering
fixtures are in `test/script_parity/source_length_order_test.elisascript`.

The candidate lives in elisa-script and selects its neighboring
`wasmbrowser-proof` project using its own resolved source directory. It is not
installed in that project, and neither the original Python script nor its
`scripts/test.sh` caller has changed. The authored public-launcher fixture
copies these siblings under one temporary workspace:

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

The observed production caller is `wasmbrowser-proof/scripts/test.sh`. It uses
`set -euo pipefail`, computes an absolute `ROOT_DIR` from its own location, and
invokes `python3 "$ROOT_DIR/scripts/check_source_length.py"` before the audit
harness and build. Therefore replacing the Python file alone cannot adopt the
Elisascript port: the accepted migration must update that one invocation to the
public Elisascript launcher, preserve the root/cwd contract, and retain
fail-fast propagation so later work does not proceed after a failed audit.
This caller edit is deliberately deferred until launcher parity is accepted;
the existing matrix tests the checker directly, not the complete `test.sh`
workflow.

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

## Authored public-launcher matrix (not executed)

`test/script_parity/source_length_launcher_test.elisascript` creates an isolated
sibling-project workspace with spaces in its name and launches both programs
from `/`. It covers missing src, regular-file src, root-symlink src, empty src,
the 600-CRLF boundary, a 601-line
mixed-terminator/Unicode/control-byte source, seven oversized hidden/Unicode/
prefix-colliding paths in exact diagnostic order, case-sensitive suffix
filtering, a file symlink, and a descendant directory-symlink cycle. Each run
asserts independently expected status/stdout/stderr as well as agreement.
Extra wrapper arguments are supplied to both programs and must be ignored.

The single-file phase now consumes 13 independently authored cases from
`test/script_parity/source_length_cases.elisa`, which imports neither the
candidate counter nor a host adapter. It covers an empty file, BOM-only content,
599/600/601 LF lines, 600/601 final unterminated lines, 600 bare CR/CRLF lines,
300 repeated CR+CRLF pairs (600 lines), mixed newline/control content (601),
601 repetitions of Unicode/control separators as one unterminated line, and
602 LF lines with its own literal diagnostic. Every expected status/stderr is
fixture data, not produced by the candidate. Missing/empty roots and multi-file
ordering/symlink cases remain separate; this is 19 ordinary case invocations
in total, each with reference-first admission and exact empty stdout.

Before creating the ordinary source directory, the harness writes a 601-line
regular file named `src` and expects silent status 0. It then makes `src` a
symlink to a separately recorded `root-target` directory containing a 601-line
source, expecting status 1 and the literal `src/boundary.elisa` diagnostic,
not the target directory's name. The outside target remains oversized during
later runs: it must not leak into an empty or ordinary `src` scan. Transition
cleanup retires only the last recorded file/link after an exact ledger-path
match, intact recorded parents, observed file/link shape and successful unlink;
failures retain the entry for centralized cleanup. This is an observational
fence, not atomic ownership. No unlink, setup or case has executed.

The fixture sources and the live neighboring Python reference are pinned
before/after the matrix. Failure reports the
fixed fixture label without dumping child output. Pure assertions in
`test/runtime/source_length_cases_test.elisa` compare the actual counter to the
literal line metadata and check byte boundaries/diagnostic fields. They have
not compiled/run and do not prove Python, filesystem or launcher behavior.
Matching directories and host/error cases still need their separate acceptance
fixtures; every authored ordinary case still needs native qualification.

The public fixture entry performs authorization checks itself, before any hash
tool or program starts; these are not only checks in the @test caller. In
addition to the existing wrapper-provided opt-in/RSS marker and pinned compiler
path, it requires `ELISASCRIPT_LOCAL_COMPILER_SHA256` and the public launcher's
path/SHA-256 variables. Reference Python (`/usr/bin/python3`), source files, and
the include closure have recorded pins. Copied assets are rehashed before use,
and original source/tool identities are checked again after cleanup. The
directory bridge pin deliberately names committed source, not concurrent dirty
edits, so today's modified bridge must fail closed pending explicit
qualification. A compiler update or source change requires deliberate repinning;
do not weaken identity checks to make the test pass.

Fixture sources are copied through the bounded UTF-8 reader with 512 KiB per
asset and 2 MiB total; hash targets have a 64 MiB size admission limit. Process
captures are capped at 64 KiB with 10,000 bounded wait polls per invocation.
The outer wrapper supplies the separate elapsed-time/RSS containment. Its
`active` environment marker is a prerequisite, not proof of an OS hard cap.
Python runs with `-I -B` to isolate imports/environment and avoid bytecode cache
writes. Cleanup unlinks only recorded fixture files/symlinks and removes known
directories in reverse order; it never recursively deletes a live project.
Partially constructed roots also reach cleanup. These bounds and authored
checks are not observed test results or proof of race-free execution.

## Full acceptance matrix (partly authored, all unexecuted)

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

Reference admission now occurs before the candidate starts: the reference must
complete with the literal expected status, empty stdout, exact stderr and no
host-error text. Candidate admission uses the same full observation after the
reference has independently passed. Authored data-only assertion bodies reject
wrong statuses/streams, host-error records and timeout-shaped records; the full
harness also includes its gated native test and must not be auto-run merely to
execute those assertions.

The public entry additionally requires
`ELISASCRIPT_SOURCE_LENGTH_LAUNCHER_QUALIFIED=1`. Shared role admission rejects
invalid/control-containing/unbounded identity paths and path/digest aliases
between launcher, pinned Python and compiler. All three roles must preflight as
bounded nonsymlink executable regular files with recognized four-byte native
container headers before any hash-tool child. Headers, hashes and qualification
markers are not provenance, no-auto-build proof, ownership or real containment.
The operator must independently qualify a prebuilt launcher and its complete
dependency closure without compiler launches. The parent compiler selectors
remain checked, but neither child receives them: replacement environments contain
only fixture PATH and LC_ALL, not compiler/authorization variables or secrets.

Checksum checks now use explicit text mode and `--`, reject stdin sentinel `-`
and NUL paths, and compare the complete escaped hash-tool record including the
literal filename and final LF. Backslash-bearing identity paths are preserved.
The hash utility and shared role/checksum model sources have pinned identities;
the utility's self-hash is not independent proof of its trustworthiness and
requires separate operator/tool qualification. Filesystem identity checks remain
observational and do not prevent concurrent replacement. No reference, candidate,
preflight, hash child, fixture or compiler ran.

Fixture setup, later rewrites and case boundaries now reject observed symlinks
or missing/nondirectory roots and recorded parents before writing or launching.
New files/directories/links refuse observed existing entries (including dangling
links); rewrites refuse an observed symlink/non-file final entry. Creation
records ancestors before descendants. Cleanup rechecks all recorded parents
before each reverse file unlink, then the required parent prefix before each
reverse directory removal and the root before its final removal. Failed-copy
entries that never appeared are skipped, while dangling final symlinks are
unlinked. Unrecorded entries are never recursively erased: nonempty-directory
removal fails and the harness reports its fixture path.

These checks are observational, not exclusive creation, inode leases,
descriptor-relative traversal/deletion, hardlink containment or atomic
no-follow rewrites. Replacement after a check can still race an operation.
The reported path is diagnostic, not proof that the original root inode remains
reachable there. Native qualification must cover partial setup, missing files,
dangling links, root/nested-parent replacement, final-file replacement, unexpected
entries and failed directory removal, with an independently retained outside
sentinel proving it is not modified/deleted. No filesystem fixture or cleanup
ran; the harness is not a sandbox for untrusted children.

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

The shared reader now admits errno sampling/retry only after native -1 from
open/stat/fstat/read. Other negative or unsupported positive status returns
fail without consuming stale EINTR. Opened descriptor shapes must be within
0..2147483647 for the selected Darwin C32 profile: zero and one remain valid
file descriptors when caller stdio is closed, unlike child/group PID rules.
Out-of-range positive descriptor returns are uncertain and never passed to
fstat/read/close as guessed ownership. After a known admitted open, a rejected
read still closes that owned descriptor and raises ReadFailed.

`test/runtime/bounded_text_return_shape_test.elisa` calls the reader's private
pure shape helpers through a module extension and covers negative, unsigned-
looking, zero/one and signed-boundary returns without calling libc. Its full
reader include still requires compiler/native ABI qualification; no fixture
compiled or ran. Numeric admission is not a descriptor ownership proof or
permission to infer that an uncertain open created no resource. Host fault
injection and cleanup/provenance qualification remain necessary. This matrix's
reader source pin is updated; other dormant matrices with the older pin remain
fail-closed pending deliberate review, not automatically accepted or repinned.

This records source work, not runtime evidence. The pure-counter, ordering, and
public-launcher tests have not run. Compiler, audit, and parity execution
remain disabled until explicitly reauthorized; the original stays authoritative.
