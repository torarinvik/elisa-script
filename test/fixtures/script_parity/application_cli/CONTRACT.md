# Application CLI contract fixture (A05)

This is a deliberately small independent reference, not a claim of full
`argparse` compatibility. Both implementations accept a declared `build` and
`test` subcommand schema, one-character short aliases, separate/equals/attached
short values, bundled short flags/value options, positive/negative booleans,
positionals, `--` passthrough, empty values overriding defaults,
command-specific defaults, and built-in root/command help. In a bundle,
boolean flags are processed left to right and a value-taking option consumes
the remaining suffix (optionally after `=`) or next argv element. Resolved
options use the shared configuration precedence model: command-line values
override defaults, including explicit empty strings. Errors are observable as
status 2 and a single stable stderr line. Automatic help styling is outside
this fixture.

`reference.py` implements the contract independently in Python.
`reference.elisascript` ports that oracle through `EsConfigCli` and
`EsConfig::resolve_config_layers`; `candidate.elisascript` exercises the same
public models as the candidate implementation. Both serialize observations
with the same small framing protocol. `expected.txt` is an independent golden
covering 17 cases:
successful parsing forms, both help levels, empty values, missing/unknown
commands, unknown options, missing values, duplicate options, unexpected
boolean values, empty/pass-through positionals, build/test defaults, and
explicit-empty-over-default precedence.

An earlier colocated-port revision at SHA-256
`76e40ad766e1604aa1c217c21e1f6f3c6561f9d84e1fdc76d19c589f1a0b8e68` passed
bounded lowering on 2026-10-15 with the pinned compiler revision
`5241b2aed51641a217ca44ac4ee116ee66ac96e6` (binary SHA-256
`8623ee8dabd773976e370f553cd91457703c4098d135a3d1648cc72609b1b915`), O0
native configuration `ca925b4f935cc7075260fe521e4040b2758d8a5fd10c850ff0ec4933361bb439`,
exit status 0 and sampled peak RSS 31,648 KiB. Retained evidence is
`.validation/ca925b4f935cc7075260fe521e4040b2758d8a5fd10c850ff0ec4933361bb439/logs/lowering.aQGpkR`
and its `.meta` file. The current sidecar is pinned by the launcher at
`75693344ce0f885c14b3ac67b07878f130be490e861e85e3e0d8f2a8e0d207c9`; that
lowering record does not qualify the current bytes. Lowering also does not
execute the 17-case matrix; the launcher test below remains the required
behavioral parity check.

`test/script_parity/application_cli_launcher_test.elisascript` invokes Python
once and the public ElisaScript launcher twice, for the oracle port and
candidate; each executes the whole matrix in-process to avoid repeated compiler
launches. It requires explicit reauthorization, the pinned compiler path,
recorded source and launcher hashes, and the active RSS guard. Each output,
status, and diagnostic stream must match the independent golden, and both
ElisaScript programs must also match Python. Runtime parity remains unqualified
until this exact test is executed under the bounded wrapper.

Two bounded `-emit test` attempts on 2026-10-15 were stopped by the 512 MiB
sampled RSS guard: the launcher matrix reached 573,440 KiB, and the smaller
reference-port golden test reached 573,776 KiB. Neither produced test output.
Their metadata is in
`.validation/559321b6196f71e963c0b223fe1a396e2ccf184c7a758ee8ba9a29ab09f0ed37/logs/test.9mN8CK.meta`
and
`.validation/559321b6196f71e963c0b223fe1a396e2ccf184c7a758ee8ba9a29ab09f0ed37/logs/test.IDAnj7.meta`;
these failures are resource-limit evidence, not behavioral parity results.
