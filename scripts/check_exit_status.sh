#!/usr/bin/env bash

# Compiler-free audit for stable launcher/process exit statuses.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/exit_status_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'exit status audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsExitStatus:' "$model"
rg -q 'include "\.\./runtime/exit_status_model\.elisa"' "$ir"
for declaration in \
    'const enum ExitOutcome of u8' \
    'struct ExitStatus:' \
    'error ExitStatusError:' \
    'def validate_exit_status\(' \
    'def exit_status_code\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'EXIT_CODE_MAX_USER' \
    'EXIT_STATUS_SIGNAL_BASE' \
    'EXIT_STATUS_MAX_SIGNAL' \
    'ExitOutcome.SourceError' \
    'ExitOutcome.CheckFailure' \
    'ExitOutcome.Cancelled' \
    'ExitStatusError.InvalidUserCode' \
    'ExitStatusError.InvalidSignal'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsExitStatus' \
    'typed_exit_status_contract_maps_user_failures_and_signals' \
    'ExitOutcome.SourceError' \
    'ExitOutcome.Signal' \
    'ExitStatusError.InvalidUserCode'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsExitStatus::ExitStatus' "$docs"
rg -q 'ES-SCRIPT-047' "$ledger"
rg -q 'P14 exit-status follow-up' "$plan"

printf 'exit status audit: bounded user, reserved failure, cancellation, and signal mappings are present\n'
