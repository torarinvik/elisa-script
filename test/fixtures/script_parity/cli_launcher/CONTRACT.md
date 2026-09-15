# CLI launcher aggregate-argument contract

This fixture records the raw-host boundary that must agree with the typed
`EsCli` parser.

- The source path is scanned against the 4 KiB filename ceiling.
- Each script argument is scanned as a bounded C string.
- Once the aggregate script-argument budget has been consumed, a scan that
  continues past the remaining budget is an `ArgumentBytes` failure.
- A scan that reaches the ordinary C-string ceiling before the aggregate
  ceiling is a `HostCString` failure.
- The aggregate classification is reported before any claim about the
  complete host string, because the bounded scan already proves that the
  launcher budget was exceeded.

The source fixture `typed_cli_launcher_budget_contract_matches_host_collector`
asserts that the raw collector and typed parser share their count and byte
ceilings. The private host-ABI enum remains implementation detail; this
contract is checked by `scripts/check_cli_model.sh` and is not an executable
parity claim until compiler validation is explicitly reauthorized.
