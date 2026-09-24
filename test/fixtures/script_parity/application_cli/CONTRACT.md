# Application CLI contract fixture (A05)

This is a deliberately small independent reference, not a claim of full
`argparse` compatibility. Both implementations accept a declared `build` and
`test` subcommand schema, one-character short aliases, separate/equals/attached
short values, positive/negative booleans, positionals, `--` passthrough, empty
values overriding defaults, command-specific defaults, and built-in root/command
help. Resolved options use the shared configuration precedence model: command-
line values override defaults, including explicit empty strings. Errors are
observable as status 2 and a single stable stderr line. Short-option bundles
and automatic help styling are outside this fixture.

`reference.py` implements the contract independently in Python. The ElisaScript
candidate calls `EsConfigCli` and `EsConfig::resolve_config_layers`, then
serializes observations with the same small framing protocol. `expected.txt` is
an independent golden covering 15 cases:
successful parsing forms, both help levels, empty values, missing/unknown
commands, unknown options, missing values, duplicate options, unexpected
boolean values, empty/pass-through positionals, build/test defaults, and
explicit-empty-over-default precedence.

`test/script_parity/application_cli_launcher_test.elisascript` invokes Python
once and the public ElisaScript launcher once; both execute the whole matrix
in-process to avoid repeated compiler launches. It requires explicit
reauthorization, the pinned compiler path, a recorded launcher hash, and the
active RSS guard, and compares each side to the golden as well as to each
other. Hash pins bind source and interpreter bytes to the fixture. The test is
not runtime evidence until the safety hold is explicitly lifted and this exact
test is executed under the bounded wrapper.
