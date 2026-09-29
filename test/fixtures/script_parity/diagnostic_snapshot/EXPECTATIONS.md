# Diagnostic snapshot audit fixture expectations

For each fixture, pass its `runner.elisa` path explicitly to both
`scripts/check_diagnostic_snapshot.sh` and the public Elisascript launcher with
`scripts/check_diagnostic_snapshot.elisascript` as the program and that fixture's
`runner.elisa` as its one script argument. This makes the input independent of
the caller's current directory.
The status, stdout, and stderr bytes must match these expectations for both
implementations.

| Fixture | Status | Stdout | Stderr |
| --- | ---: | --- | --- |
| `positive` | 0 | `diagnostic snapshot audit: 2 fields covered (execution intentionally excluded)\n` | empty |
| `compact_fields` | 0 | `diagnostic snapshot audit: 2 fields covered (execution intentionally excluded)\n` | empty |
| `unicode_runner.elisa` | 0 | `diagnostic snapshot audit: 2 fields covered (execution intentionally excluded)\n` | empty |
| `missing_fingerprint` | 1 | empty | `diagnostic snapshot audit: fingerprint omits entrypoint_error\n` |
| `missing_fingerprint_source` | 1 | empty | `diagnostic snapshot audit: fingerprint omits source\n` |
| `missing_equality` | 1 | empty | `diagnostic snapshot audit: structural equality omits entrypoint_error\n` |
| `missing_equality_source` | 1 | empty | `diagnostic snapshot audit: structural equality omits source\n` |
| `missing_operations` | 1 | empty | `diagnostic snapshot audit: missing snapshot operations\n` |

The launcher also creates bounded temporary byte fixtures and compares both
implementations against these tuples:

| Generated case | Status | Stdout | Stderr |
| --- | ---: | --- | --- |
| zero-byte runner source | 1 | empty | `diagnostic snapshot audit: no diagnostic fields found\n` |
| absent runner path inside the owned temporary root | 1 | empty | `diagnostic snapshot audit: missing runner source\n` |
| exactly 262,144 source bytes | 0 | `diagnostic snapshot audit: 2 fields covered (execution intentionally excluded)\n` | empty |
| 262,145 source bytes | 1 | empty | `diagnostic snapshot audit: runner source exceeds audit limit\n` |
| CRLF-normalized positive source | 0 | `diagnostic snapshot audit: 2 fields covered (execution intentionally excluded)\n` | empty |
| bare carriage return | 1 | empty | `diagnostic snapshot audit: bare carriage return is unsupported\n` |
| 257 diagnostic fields | 1 | empty | `diagnostic snapshot audit: diagnostic field count exceeds audit limit\n` |
| 129-byte diagnostic field name | 1 | empty | `diagnostic snapshot audit: diagnostic field name exceeds audit limit\n` |
| one extra CLI operand | 2 | empty | `usage: diagnostic snapshot audit [runner-source]\n` |

The positive fixture proves the `execution` exclusion remains intentional.
`compact_fields` uses declarations with no space before the colon and an
optional space before the colon; it ensures field-name extraction follows the
parser's token-based treatment of insignificant whitespace. The four
field-omission fixtures cover every required field in each comparison
operation. `unicode_runner.elisa` places valid non-ASCII text in comments and
after field types while keeping the audited identifiers ASCII. The generated
cases exercise raw CRLF/bare-CR bytes, the exact source-byte ceiling,
field-count/name ceilings, empty and missing-input behavior, and the extra-
operand usage boundary. The missing path is already absolute but deliberately
is not passed through `path_real`, since it must remain absent. None of these
expectations have been executed; the standing compiler validation hold remains
in force.

The shell reference and Elisascript candidate both resolve an omitted or empty
path relative to their own script locations. The public-launcher parity source
also runs both the omitted-argument and explicit-empty-argument forms with `/`
as the working directory and compares their process results. These cases
intentionally have no checked-in golden tuple: their output depends on the
current runner source, while their purpose is to verify script-relative
default-path behavior outside the repository working directory.

`test/script_parity/diagnostic_snapshot_launcher_test.elisascript` automates
the fixture table as a process comparison: `/bin/bash` runs the shell reference,
and the configured public Elisascript launcher runs the candidate. Both receive
the same canonical absolute fixture path; each result must match both the other
process and the recorded tuple above. Both child processes use an identical
replacement environment containing only a controlled `PATH` and `LC_ALL=C`, so
shell startup hooks and unrelated inherited configuration cannot affect one
side alone. The source requires
`ELISASCRIPT_VALIDATION_REAUTHORIZED=1`, the pinned local compiler path, an
absolute `ELISASCRIPT_PUBLIC_LAUNCHER`, and its supplied SHA-256, checked before
and after all cases. Run it only through the bounded validation wrapper after
explicit reauthorization. This source covers the checked-in fixtures plus
bounded temporary byte/resource cases. The recorded digest must be tied to the
intended launcher build separately, and the path-based artifact must remain
immutable during the run; pre/post hashing does not prevent a transient
replacement between checks.
