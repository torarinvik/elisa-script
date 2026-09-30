# Native process probe for small-wrapper parity

`probe.c` is an independent, bounded native dummy tool for lint/test/build
wrappers. It is not an Elisascript implementation dependency or a migrated
automation script. A C oracle deliberately avoids making both the runner and
its observed child depend on the same Elisa parser/interpreter. The expected
observation encoder is separately implemented in Elisa at
`test/script_parity/process_probe_model.elisa`, with authored literal-golden,
presence/NUL, argument-limit, byte-order, and aggregate-budget fixtures in
`process_probe_model_test.elisa`. None has compiled or run.

The probe launches no child, touches no project file, and has no training,
network, SSH, shell, Ruff, or pytest dependency. It reads only argv, physical
cwd, five named environment values, one exit-status selector, and stdin.
It never dumps the whole environment. Qualify a compiled probe once under the
existing validation controls, then supply its absolute path and recorded binary
SHA-256 to isolated wrapper fixtures. Do not introduce an on-demand compiler
loop into each parity case. Record source/compiler/binary identities; a
different compiler or tool version is a new qualification, not implicit parity.

## Binary stdout protocol: ESPROBE2

All integer lengths are unsigned 32-bit **big-endian** values. Payloads are raw
bytes, not UTF-8 text, escaped strings, newline-delimited records, or C strings.
There is no alignment padding or final newline.

| Order | Field |
| --- | --- |
| 1 | Eight ASCII bytes `ESPROBE2` |
| 2 | Argument count, excluding argv[0], as u32 |
| 3 | For each argument: u32 length, then exactly those bytes |
| 4 | Physical cwd: u32 length, then exactly those bytes |
| 5 | PYTHON_BIN presence byte (0/1); if 1, u32 length + bytes |
| 6 | RUFF_BIN presence byte (0/1); if 1, u32 length + bytes |
| 7 | ELISASCRIPT_PARITY_PROBE_MARKER presence byte (0/1); if 1, u32 length + bytes |
| 8 | PWD presence byte (0/1); if 1, u32 length + bytes |
| 9 | OLDPWD presence byte (0/1); if 1, u32 length + bytes |
| 10 | Stdin: u32 length, then exactly those bytes |
| 11 | Two terminal bytes: `00 ff` |

A present empty value has a `1` presence byte and a zero length. An absent
value has only a `0` presence byte. Empty arguments still have length fields.
Stdin can contain any bytes, including NUL, invalid UTF-8, and final partial
lines. The probe deliberately excludes argv[0]/PID/timing so independently
located dummy executable copies can produce the same observations. This does
not prove executable-selection identity; the fixture must also pin the
selected binary and assert the selected environment/cwd/argv.

Normal stderr is exactly 14 bytes: ASCII `probe-stderr` followed by `00 ff`,
with no final newline. This catches output loss, UTF-8 coercion, accidental
print-newline framing, and capture-versus-inherit mistakes. Compare stdout and
stderr as bytes, not text normalized by a JSON reader or splitlines adapter.

The exit status defaults to 0. `ELISASCRIPT_PARITY_PROBE_EXIT_STATUS`, if present,
must contain one to three decimal digits whose value is 0..255; leading zeros
are allowed. Valid selectors return that status *after* emitting both frames.
The selector itself is not an observed environment field. Set it identically
for reference/candidate and independently assert statuses such as 0/1/2/23.

## Bounds and failure policy

At most 256 arguments are admitted. Argument, cwd, and the five recorded
environment payloads share a 65,536-byte aggregate text budget, excluding their
C terminators and protocol framing. Cwd has a 4,096-byte buffer (thus at most
4,095 payload bytes). Stdin is at most 65,536 bytes, with a one-byte overflow
probe. Maximum normal stdout is 132,143 bytes; admit at least that much combined
stdout/stderr in the outer runner (132,157 total), rather than a 64 KiB capture.
The implementation uses fixed, modest stack buffers; those are not an OS RSS
cap and do not bound libc/toolchain allocations.

Argument/text/stdin/status preflight errors emit no stdout frame, return 125,
and report `process probe: invalid input or host I/O failure` plus newline on
stderr. The same diagnostic is used for host read/cwd/output errors; output
errors may leave a partial frame and must not count as a normal probe result.
Stderr-write failure returns 125 without claiming the diagnostic was delivered.
Signal termination, SIGPIPE, TTY input and process replacement are unspecified
by this dummy tool and must have separate tests.

Stdin must be a closed, bounded fixture input supplied by the differential
runner, not an interactive terminal or an unbounded pipe. Reading to EOF can
block; the external process-tree deadline/RSS guard remains mandatory. The
probe's byte budgets do not replace that guard or user reauthorization.

## Applying it to the current small ports

For canonical tests, place the qualified binary at fixture `.venv/bin/python`
or name it through PYTHON_BIN, then expect exactly the pytest argv prefix plus
literal extras from the contract. For lint, place it as `ruff` on fixture PATH
or name it through RUFF_BIN, then expect the four declared lint operands. Use
temporary paths containing spaces, unset versus empty variables, raw stdin,
and nonzero statuses. Do not invoke the live tools or original project trees.

Before using the probe for either wrapper, independently qualify its literal
golden bytes, absent/empty cases, input/argv boundaries, maximum counts/budgets,
invalid selectors, overflow rejection and stream-failure behavior. A fixture
must not call the probe to compute its own expected output. The Elisa model
can encode independently supplied observations, but its golden/boundary tests
also need to pass. Equal outputs from two programs are insufficient evidence
if neither agrees with the independent expected frame.

`test/script_parity/canonical_wrappers_launcher_test.elisascript` now authors a
direct literal-golden probe check followed by ten ordinary wrapper cases. It
requires an already-built, separately qualified probe path/hash; it does not
compile one or silently treat source-only probe/model fixtures as qualified.
The direct golden check is an extra runtime prerequisite, not a substitute for
the full boundary/failure qualification listed above. All cases remain unrun.

No compiler, probe, model fixture, wrapper, or parity process was launched for
this change. The standing validation hold still applies.
