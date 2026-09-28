# A06/C07 Cargo manifest parity slice

This fixture compares Python's standard-library `tomllib` with the Elisascript
TOML file reader against the pinned snapshot in
`test/runtime/config_toml_cargo_fixture.toml`. Both sides emit the same ordered
projection of workspace resolver/package settings, every workspace member,
and selected dependency fields including an inline-table array.

The candidate intentionally uses the public file-reading path rather than
parsing a duplicated string literal. Exact output is checked against
`expected.txt` as well as against the independent Python process. This covers
one real project-shaped manifest slice; it does not imply full TOML 1.0
compatibility, exhaustive Cargo manifest semantics, or parity for the other
observed `pyproject.toml` and Hugo configuration files.

The test is gated by explicit validation reauthorization, an active RSS guard,
and both compiler variables being pinned to the local StructPy compiler. Its
sources, interpreter, input snapshot, and golden are SHA-256 pinned. It remains
unqualified until that gated launcher is run under the approved bounded
validation workflow.
