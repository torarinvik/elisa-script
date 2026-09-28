# A06/C07 Cargo manifest parity slice

This fixture compares Python's standard-library `tomllib` with the Elisascript
TOML file reader against pinned snapshots of the observed
`WasmBrowser/Cargo.toml` and `neural-computer-agent/pyproject.toml`. Both sides
emit the same ordered projection of Cargo workspace resolver/package
settings, every workspace member, and selected dependency fields including an
inline-table array. The pyproject projection covers project/build metadata,
arrays beneath nested tool tables, and pytest marker text.

The candidate intentionally uses the public file-reading path rather than
parsing duplicated string literals. Exact output is checked against
`expected.txt` as well as against the independent Python process. These are
representative real-project slices; they do not imply full TOML 1.0
compatibility, exhaustive Cargo/pyproject semantics, or parity for the
observed Hugo configuration.

The test is gated by explicit validation reauthorization, an active RSS guard,
and both compiler variables being pinned to the local StructPy compiler. Its
sources, interpreter, input snapshot, and golden are SHA-256 pinned. It remains
unqualified until that gated launcher is run under the approved bounded
validation workflow.
