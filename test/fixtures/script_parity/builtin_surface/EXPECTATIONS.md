# Builtin-surface port fixtures

Pass the absolute fixture root as the one argument to both
`scripts/check_builtin_surface.sh` and the public Elisascript launcher using
`scripts/check_builtin_surface.elisascript`. The candidate and reference should
have the following observable results. These expectations are static and have
not been executed while compiler validation is suspended.

| Fixture | Status | Stdout | Stderr |
| --- | ---: | --- | --- |
| `positive` | 0 | `semantic_seed_count\t8\nlowerer_global_count\t1\nbuiltin surface audit: semantic seeds cover all direct global spellings; registry identity handles global lowering\n` | empty |
| `missing_registry_row` | 1 | `semantic_seed_count\t1\nlowerer_global_count\t1\n` | `missing_registry_row\tlegacy_call\n` |
| `mismatched_consumer` | 1 | `semantic_seed_count\t2\nlowerer_global_count\t1\n` | `missing_registry_row\tunregistered_call\nmissing_semantic_seed\tunregistered_call\n` |

`missing_registry_row` keeps the direct consumer in the legacy semantic seed
while removing it from `typed_builtin_names()`. This fixture proves that the
audit checks registry identity instead of passing solely because the old seed
still masks the missing row. `mismatched_consumer` adds a direct lowerer spelling
that appears in neither authority and must report both gaps.
Its semantic source also includes an escaped-quote comment before a later
`add_symbol("consumer_only")` text match, pinning parity with the reference's
independent raw-source regex searches.
The positive registry fixture gives the first following `def` line a quoted
comment token, pinning the shell reference's inclusive `sed` range endpoint.
Text after its closing quote pins `rg -o`'s non-overlapping match behavior: the
closing quote of one match is not also treated as the opener of another name.
The positive semantic fixture also repeats the seed marker in a comment after
an earlier `]`; the shell AWK rule resets its terminator position to the suffix
of that repeated marker, so the later `followup_seed` remains captured.
The positive registry fixture also adds a later marker-prefix function; the
shell's `sed` address range restarts there, and its `registry_supplement` name
contributes to the distinct seed count.
The positive semantic fixture also includes quoted hyphenated and digit-leading
near-misses; they must not be counted as identifiers by either scanner.

The source-only launcher harness creates its generated root with spaces and
shell metacharacters in the path. It checks an owned empty root where the
first required semantic file is absent. Both implementations must return
status 2, no stdout, and
`builtin surface: missing source file: <absolute-symbols-path>\n`. It then
generates two bounded failure inputs: one semantic source of 1,048,577 bytes
and one semantic seed containing 65,537 identifier matches. Each must return
status 2, no stdout, and respectively
`builtin surface: source file exceeds audit limit: <absolute-symbols-path>\n`
or `builtin surface: identifier match count exceeds audit limit\n`. The shell
reference and Elisascript candidate share these 1 MiB per-file and 65,536
raw-match ceilings. Unreadable files and concurrent source-file mutation remain
outside the current parity fixtures.

The process-level parity harness also invokes both scripts without a source-root
argument while the child working directory is `/`. It compares reference and
candidate status/stdout/stderr directly (rather than pinning checkout-specific
counts) to ensure each implementation defaults to the repository containing
its own script, not the caller's working directory.

The launcher also compares both scripts with `/` as the explicit source root.
The shell reference appends `/` plus each relative source path, preserving a
double-leading slash in diagnostics (`//vendor/...`); the candidate preserves
that same displayed spelling while its filesystem `Path` resolves the input.

The launcher digest is checked against a caller-supplied SHA-256 before and
after the matrix. This detects changes relative to that supplied value but
does not establish trusted launcher build provenance.
