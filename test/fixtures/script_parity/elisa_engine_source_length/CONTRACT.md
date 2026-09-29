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
platform-specific path collation are not qualified. No candidate, reference,
compiler, or parity fixture has run. Before acceptance, add a gated public-
launcher matrix with independent literal expectations for the plan, all roots,
suffix edge cases, component-sort collisions, line boundaries, symlinks, and
read/discovery errors; then qualify it explicitly under the existing execution
authorization policy.
