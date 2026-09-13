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
for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger"; do
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
    'struct ProcessTerminationReapBatch:' \
    'process_termination_sort_reap_identities' \
    'def report_process_termination_reaps\(' \
    'struct ProcessTerminationIdentity:' \
    'process_termination_identity_valid' \
    'expected_member.reaped' \
    'session.members\[member_index\].reaped <- true' \
    'canonicalize_process_termination_members' \
    'process_termination_sort_members' \
    'process_termination_sift_members' \
    'process_termination_member_index' \
    'ProcessTerminationError.MemberOrderInvalid' \
    'ProcessTerminationError.ReapCountInvalid' \
    'ProcessTerminationError.ReapIdentityInvalid' \
    'ProcessTerminationError.ReapBatchEmpty' \
    'ProcessTerminationError.ReapBatchTooLarge' \
    'reaped_count' \
    'ProcessTerminationState.Planned and' \
    'ProcessTerminationState.Running and' \
    'session.state == ProcessTerminationState.GracefulRequested and \(session.polls != 0 or session.force_attempts != 0 or session.reaped_members != 0\)' \
    'session.state == ProcessTerminationState.GracefulWaiting and \(session.force_attempts != 0 or session.reaped_members != 0\)' \
    'session.state == ProcessTerminationState.ForceRequested and session.force_attempts == 0' \
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
    'report_process_termination_reaps' \
    'ProcessTerminationReapBatch\{members: \[ProcessTerminationIdentity\{pid: 103, start_token: 3\}' \
    'wrong_generation' \
    'unknown_member' \
    'bad_mixed_batch' \
    'duplicate_in_batch' \
    'empty_reap_batch' \
    'oversized_reap_batch' \
    'duplicate_reap' \
    'forged_reap_count' \
    'impossible_graceful_reap' \
    'graceful_poll' \
    'waiting_force_attempt' \
    'force_without_attempt' \
    'session.members\[1\].reaped' \
    'ProcessTerminationEvent.Cancel' \
    'canonicalize_process_termination_members' \
    'ProcessTerminationError.MemberOrderInvalid' \
    'ProcessTerminationError.DuplicateMember' \
    'ProcessTerminationError.ReapIdentityInvalid' \
    'ProcessTerminationError.ReapBatchEmpty' \
    'ProcessTerminationError.ReapBatchTooLarge' \
    'ProcessTerminationError.AccountingInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsProcessTermination::ProcessTerminationSession' "$docs"
rg -q 'ES-SCRIPT-037' "$ledger"
printf 'process termination audit: canonical bounded membership and identity-bound graceful/force reaping are present\n'
