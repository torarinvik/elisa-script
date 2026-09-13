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
| `missing_fingerprint` | 1 | empty | `diagnostic snapshot audit: fingerprint omits entrypoint_error\n` |
| `missing_fingerprint_source` | 1 | empty | `diagnostic snapshot audit: fingerprint omits source\n` |
| `missing_equality` | 1 | empty | `diagnostic snapshot audit: structural equality omits entrypoint_error\n` |
| `missing_equality_source` | 1 | empty | `diagnostic snapshot audit: structural equality omits source\n` |
| `missing_operations` | 1 | empty | `diagnostic snapshot audit: missing snapshot operations\n` |

The positive fixture proves the `execution` exclusion remains intentional.
`compact_fields` uses declarations with no space before the colon and an
optional space before the colon; it ensures field-name extraction follows the
parser's token-based treatment of insignificant whitespace. The four
field-omission fixtures cover every required field in each comparison
operation. Static source inspection shows CRLF normalization and bare-CR
rejection (`status 1`, stderr
`diagnostic snapshot audit: bare carriage return is unsupported\n`), but this
matrix does not yet contain raw CRLF/bare-CR byte fixtures or CLI/resource-limit
boundary cases. Add those before accepting newline and boundary parity. None of
these expectations have been executed; the standing compiler validation hold
remains in force.

The shell command still resolves its omitted-path default relative to its own
location. The Elisascript convenience default is relative to the caller's
current directory; pass an explicit path outside the repository root. That
no-argument path-location difference is not claimed as A03 parity.
