#!/usr/bin/env bash

# Compiler-free audit for bounded process-session lifecycles.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/process_session_model.elisa"
process_model="$repo_root/src/runtime/process_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
command_policy_fixture="$repo_root/test/driver/process_session_command_limits.elisascript"
exit_deadline_fixture="$repo_root/test/driver/process_session_exit_deadline.elisascript"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$process_model" "$ir" "$fixture" "$command_policy_fixture" "$exit_deadline_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'process session audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsProcessSession:' \
    'PROCESS_SESSION_MAX_POLLS' \
    'PROCESS_SESSION_MAX_OUTPUT_BYTES' \
    'def process_session_for_command(' \
    'def session_elapsed_state_valid(' \
    'def session_next_elapsed_micros(' \
    'elapsed_sampled: bool = false' \
    'ProcessSessionState.TimingOut' \
    'ProcessSessionEvent.TimeoutAck' \
    'ProcessSessionError.TimeoutNotReady' \
    'const enum ProcessSessionState of u8:' \
    'const enum ProcessSessionEvent of u8:' \
    'struct ProcessSession:' \
    'error ProcessSessionError:' \
    'def validate_process_session(' \
    'def advance_process_session('; do
    rg -Fq "$declaration" "$model"
done

rg -Fq 'terminal Exit receipts for finite-deadline commands must include' "$model"
rg -Fq 'next_elapsed_micros: u64 = try session_next_elapsed_micros(session, elapsed_micros_delta, elapsed_sampled)' "$model"
rg -Fq 'finite_deadline_exit_requires_a_clock_sample' "$exit_deadline_fixture"
rg -Fq 'exit_observed_at_deadline_enters_timeout_cleanup' "$exit_deadline_fixture"
rg -Fq 'exit_observed_before_deadline_preserves_exit_status' "$exit_deadline_fixture"
rg -Fq 'session.state == ProcessSessionState.TimingOut' "$exit_deadline_fixture"

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
    'session.max_output_bytes > session.command.capture_output_limit_bytes' \
    'session.command.timeout_micros != 0 and session.elapsed_micros == session.command.timeout_micros' \
    'session.elapsed_micros <- next_elapsed_micros' \
    'ExitNotReady' \
    'CancelNotReady' \
    'AccountingInvalid'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'session_inherits_the_command_capture_ceiling' "$command_policy_fixture"
rg -Fq 'session_cannot_widen_the_command_capture_ceiling' "$command_policy_fixture"
rg -Fq 'poll_elapsed_time_enforces_the_command_deadline' "$command_policy_fixture"
rg -Fq 'deadline_overshoot_saturates_at_timeout' "$command_policy_fixture"
rg -Fq 'command_can_exit_before_deadline' "$command_policy_fixture"
rg -Fq 'timeout_ack_requires_cleanup_to_be_pending' "$command_policy_fixture"
rg -Fq 'ProcessSessionError.ClockSampleMissing' "$command_policy_fixture"
rg -Fq 'ProcessSessionError.InvalidLimit' "$command_policy_fixture"

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

printf 'process session audit: bounded streams/polls, typed outcomes, timeout accounting, and cancellation are present\n'
