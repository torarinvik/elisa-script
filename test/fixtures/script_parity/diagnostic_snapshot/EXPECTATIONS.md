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
| `missing_fingerprint` | 1 | empty | `diagnostic snapshot audit: fingerprint omits entrypoint_error\n` |
| `missing_fingerprint_source` | 1 | empty | `diagnostic snapshot audit: fingerprint omits source\n` |
| `missing_equality` | 1 | empty | `diagnostic snapshot audit: structural equality omits entrypoint_error\n` |
| `missing_equality_source` | 1 | empty | `diagnostic snapshot audit: structural equality omits source\n` |
| `missing_operations` | 1 | empty | `diagnostic snapshot audit: missing snapshot operations\n` |

The positive fixture proves the `execution` exclusion remains intentional.
The four field-omission fixtures cover every required field in each comparison
operation. LF and CRLF sources are supported; a source containing a bare CR is
rejected with status 1 and stderr
`diagnostic snapshot audit: bare carriage return is unsupported\n`. These
fixtures and expectations are not yet executed; the standing compiler validation
hold remains in force.

The shell command still resolves its omitted-path default relative to its own
location. The Elisascript convenience default is relative to the caller's
current directory; pass an explicit path outside the repository root. That
no-argument path-location difference is not claimed as A03 parity.
