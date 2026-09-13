#!/usr/bin/env bash

# Compiler-free audit for bounded process-group termination and reaping.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/process_termination_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'process termination audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsProcessTermination:' "$model"
rg -q 'include "\.\./runtime/process_termination_model\.elisa"' "$ir"
for declaration in \
    'const enum ProcessTerminationState of u8' \
    'const enum ProcessTerminationEvent of u8' \
    'struct ProcessTerminationPolicy:' \
    'struct ProcessTerminationMember:' \
    'struct ProcessTerminationSession:' \
    'error ProcessTerminationError:' \
    'def validate_process_termination\(' \
    'def advance_process_termination\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'Limits::MEMBERS' \
    'Limits::POLLS' \
    'Limits::FORCE_ATTEMPTS' \
    'start_token' \
    'RootNotOwned' \
    'ProcessTerminationEvent.RequestGraceful' \
    'ProcessTerminationEvent.GracefulAck' \
    'ProcessTerminationEvent.RequestForce' \
    'ProcessTerminationEvent.ForceAck' \
    'ProcessTerminationEvent.ReportReaped' \
    'ProcessTerminationError.ReapCountInvalid' \
    'ProcessTerminationState.Planned and' \
    'ProcessTerminationState.Running and' \
    'session.state == ProcessTerminationState.Reaped' \
    'ProcessTerminationError.PollLimitExceeded' \
    'ProcessTerminationError.ForceLimitExceeded'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsProcessTermination' \
    'typed_process_termination_contract_bounds_escalation_and_reaping' \
    'ProcessTerminationEvent.RequestGraceful' \
    'ProcessTerminationEvent.RequestForce' \
    'ProcessTerminationEvent.ReportReaped' \
    'ProcessTerminationEvent.Cancel' \
    'ProcessTerminationError.DuplicateMember' \
    'ProcessTerminationError.AccountingInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsProcessTermination::ProcessTerminationSession' "$docs"
rg -q 'ES-SCRIPT-037' "$ledger"
rg -q 'P10 process-group termination follow-up' "$plan"

printf 'process termination audit: bounded graceful/force escalation and complete reaping are present\n'
