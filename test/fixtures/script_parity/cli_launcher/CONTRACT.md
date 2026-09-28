# CLI launcher aggregate-argument contract

This fixture records the raw-host boundary that must agree with the typed
`EsCli` parser.

- The source path is scanned against the 4 KiB filename ceiling.
- Each script argument is scanned as a bounded C string.
- Once the aggregate script-argument budget has been consumed, a scan that
  continues past the remaining budget is an `ArgumentBytes` failure.
- A scan that reaches the ordinary C-string ceiling before the aggregate
  ceiling is a `HostCString` failure.
- `--test` accepts repeated exact-name `--select NAME` options before the
  source path; selected functions execute in source order. Duplicate or
  unknown selections are rejected. Trailing values after the source remain
  unsupported and are rejected as `TestArgumentsUnsupported`.
- Test reports default to Human and accept `--format human|json|junit`.
  JSON/JUnit are rejected outside `--test`, and `--color always` is rejected
  for machine-readable formats so report bytes remain parseable.
- The aggregate classification is reported before any claim about the
  complete host string, because the bounded scan already proves that the
  launcher budget was exceeded.

The source fixture `typed_cli_launcher_budget_contract_matches_host_collector`
asserts that the raw collector and typed parser share their count and byte
ceilings. The private host-ABI enum remains implementation detail; this
contract is checked by `scripts/check_cli_model.sh` and is not an executable
parity claim until compiler validation is explicitly reauthorized.

`scripts/check_cli_model.elisascript` is a bounded source-only port of that
audit. It reads the same seven inputs with per-file and aggregate byte caps,
then checks the contract markers without launching `rg` or another child.
Source presence is not yet shell/Elisascript parity evidence; the comparison
remains gated by the explicit compiler-validation hold.

`test/script_parity/cli_model_launcher_test.elisascript` is the gated
public-launcher comparison for the clean-repository success case. It pins the
reference, candidate, bounded reader, and `rg` identities, requires the pinned
compiler-path environment plus the active RSS guard, and compares exact exit
status/stdout/stderr. Missing-input/error fixtures and an executed evidence
bundle remain open.
