# Elisa Engine source-length audit

Reference: `../elisa-engine/scripts/check_source_length.py`.
Candidate: `scripts/check_elisa_engine_source_length.elisascript`.
The original Python script and its callers are unchanged.

The Python checker resolves its own repository root, considers
`Elisa_Engine_Architecture_and_Plan.md` first when it is a file, then walks
these roots in this exact order: `src`, `test`, `proof`, `examples`, `scripts`,
`native`, `backends`, and `docs`. Within each root it sorts matching paths using
`pathlib.Path` ordering. A path is included only when `Path.suffix` is exactly
one of `.elisa`, `.elisascript`, `.cpp`, `.h`, `.inc`, `.py`, `.gd`, or `.md`;
thus a lone dot-prefixed name such as `.md` has no suffix and is ignored.
Each file is read as strict UTF-8 text with universal-newline iteration. More
than 600 logical lines emits one stderr record per file and exits 1; otherwise
the checker prints its success sentence and exits 0.

The candidate targets the sibling `elisa-engine` directory from its installed
Elisa Projects layout and accepts no meaningful arguments, like the reference.
It preserves the plan/root ordering, exact suffix set, per-root path ordering,
600-line threshold, and ordinary success/violation output. Its reader uses a
fixed 16 KiB buffer and strict incremental UTF-8/newline state. Matching file
symlinks are read through their targets, descendant directory symlinks are not
traversed, and the configured root itself is inspected as a directory.

This is only a source port and pure-policy fixture. Discovery/read errors are
not Python-traceback compatible: the candidate fails closed with a concise
diagnostic and status 2, while the reference raises the host Python exception.
Directory-enumeration behavior can also vary by Python version. The shared
reader currently uses the Darwin POSIX adapter; invalid-UTF-8 filenames and
platform-specific path collation are not qualified.

`test/script_parity/elisa_engine_source_length_launcher_test.elisascript` adds
a dormant public-launcher matrix. It pins the original Python file, a fixture
snapshot, candidate/include closure, launcher roles, and tool identities; uses
fresh sibling-project roots with spaces; reference-admits exact status/stdout/
stderr before starting the candidate; then compares an independent literal
observation. The process adapter's top-level source is pinned to its committed
snapshot; its transitive test/compiler/runtime closure still needs independent
operator qualification. Authored cases cover no oversized source (with only the staged
short reference beneath `scripts`), a non-directory root, 600/601
universal-newline boundaries, all configured roots, path-component
ordering, every accepted suffix, excluded dot/uppercase/other suffixes, file
and directory symlinks, ignored arguments, unrelated cwd, and exact output.
Cleanup removes only ledgered files/links and known directories in reverse
order, with recorded-parent checks. The entry requires explicit reauthorization,
the active external RSS marker, the pinned local compiler selection, and a
qualified public launcher; authorization markers/header checks are not runtime
provenance or hard containment. The matrix and candidate remain uncompiled and
unrun. Error parity, native qualification, external time/RSS containment, and
observed results are still required before acceptance.
