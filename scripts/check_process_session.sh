#!/usr/bin/env bash

# Compiler-free audit for bounded process-session lifecycles.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/process_session_model.elisa"
process_model="$repo_root/src/runtime/process_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$process_model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'process session audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsProcessSession:' \
    'PROCESS_SESSION_MAX_POLLS' \
    'PROCESS_SESSION_MAX_OUTPUT_BYTES' \
    'const enum ProcessSessionState of u8:' \
    'const enum ProcessSessionEvent of u8:' \
    'struct ProcessSession:' \
    'error ProcessSessionError:' \
    'def validate_process_session(' \
    'def advance_process_session('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'session_stream_handle_valid' \
    'session_handle_ids_distinct' \
    'stdin_resource_id' \
    'session.command.stdin_mode' \
    'OutputLimitExceeded' \
    'PollLimitExceeded' \
    'InvalidOutcome' \
    'session.state == ProcessSessionState.Exited' \
    'session.exit_status <- exit_status' \
    'session.exit_status < 0' \
    'session.state != ProcessSessionState.Exited and session.exit_status != 0' \
    'session.state == ProcessSessionState.Created' \
    'session.state == ProcessSessionState.Created and session.result_kind != ProcessResultKind.SpawnFailure' \
    'session.state == ProcessSessionState.Running or session.state == ProcessSessionState.Collecting' \
    'session.state == ProcessSessionState.Failed and session.result_kind != ProcessResultKind.HostIoFailure' \
    'session.state == ProcessSessionState.TimedOut' \
    'ExitNotReady' \
    'CancelNotReady' \
    'AccountingInvalid'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/process_session_model.elisa"' "$ir"
rg -Fq 'using EsProcessSession' "$fixture"
for fixture_pattern in \
    'typed_process_session_contract_bounds_streams_polls_and_outcomes' \
    'ProcessSessionEvent.Spawn' \
    'ProcessSessionEvent.Stdout' \
    'ProcessSessionEvent.Exit' \
    'ProcessSessionEvent.CancelAck' \
    'forged_active_outcome' \
    'forged_timeout_status'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'session.exit_status == 17' "$fixture"

rg -Fq 'EsProcessSession binds that command value to an adapter lifecycle' "$docs"
rg -Fq 'ES-SCRIPT-007 | EsProcessSession' "$ledger"
rg -Fq 'explicit EsProcessSession contract' "$plan"

printf 'process session audit: distinct spawn handles, bounded streams/polls, typed outcomes, and cancellation are present\n'
