#!/usr/bin/env bash

# Compiler-free audit for bounded parallel process-batch scheduling.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/process_batch_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
dispatch_fixture="$repo_root/test/runtime/process_batch_dispatch_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture_file" "$dispatch_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'process batch audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsProcessBatch:' "$model"
rg -q 'include "\.\./runtime/process_batch_model\.elisa"' "$ir"
for declaration in \
    'const module Limits:' \
    'const enum ProcessBatchFailureMode of u8' \
    'const enum ProcessBatchState of u8' \
    'const enum ProcessBatchJobState of u8' \
    'AwaitingReap' \
    'const enum ProcessBatchEvent of u8' \
    'ReapAck' \
    'LaunchAt' \
    'struct ProcessBatchPolicy:' \
    'struct ProcessBatchJob:' \
    'struct ProcessBatchDispatch:' \
    'struct ProcessBatchSession:' \
    'error ProcessBatchError:' \
    'def validate_process_batch\(' \
    'def advance_process_batch\('; do
    rg -q "$declaration" "$model"
done
rg -q 'def admit_next_process_batch_job\(' "$model"
rg -q 'def admit_process_batch_job\(' "$model"
rg -q 'def validate_process_batch_dispatch\(' "$model"

for boundary in \
    'Limits::JOBS' \
    'Limits::PARALLEL' \
    'Limits::ATTEMPTS' \
    'process_batch_pending_index' \
    'process_batch_all_terminal' \
    'process_batch_job_requires_attempt' \
    'ProcessBatchFailureMode.FailFast' \
    'ProcessBatchFailureMode.Aggregate' \
    'ProcessBatchEvent.Retry' \
    'ProcessBatchEvent.CancelAck' \
    'ProcessBatchError.ParallelLimitExceeded' \
    'ProcessBatchError.DuplicateJobId' \
    'ProcessBatchError.RetryNotReady' \
    'ProcessBatchError.StaleAttempt' \
    'ProcessBatchError.DispatchMismatch' \
    'ProcessBatchError.ReapNotReady' \
    'attempt_token' \
    'reap_acknowledged' \
    'queued' \
    'session.jobs\[pending\].attempts >= session.policy.max_attempts' \
    'ProcessBatchState.Planned and' \
    'ProcessBatchState.Succeeded and' \
    'ProcessBatchState.Failed and' \
    'session.state == ProcessBatchState.Draining and' \
    'session.state <- ProcessBatchState.Failed if session.fail_fast_latched' \
    'ProcessBatchState.Draining' \
    'ProcessBatchState.Cancelled and' \
    'ProcessBatchState.Running and unfinished == 0' \
    'ProcessBatchState.Cancelling and unfinished == 0' \
    'session.failed > session.jobs.count - session.completed' \
    'session.fail_fast_latched and session.policy.failure_mode != ProcessBatchFailureMode.FailFast' \
    'cancelled == 0'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsProcessBatch' \
    'typed_process_batch_contract_bounds_parallel_retry_and_cancel' \
    'ProcessBatchEvent.Launch' \
    'ProcessBatchEvent.Retry' \
    'ProcessBatchEvent.CancelAck' \
    'ProcessBatchError.DuplicateJobId' \
    'ProcessBatchError.AccountingInvalid' \
    'forged_completed_cancelled' \
    'forged_failed' \
    'forged_failed_with_pending' \
    'forged_draining' \
    'forged_aggregate_latch' \
    'ProcessBatchEvent.ReapAck' \
    'StaleAttempt' \
    'retry_without_reap' \
    'stale_reap_receipt' \
    'stale_reap_again' \
    'fail_fast_cancel' \
    'fail_fast_cancel_before_reap' \
    'fail_fast_retry_policy' \
    'fail_fast_retry.fail_fast_latched' \
    'forged_running_complete' \
    'forged_cancelling_complete' \
    'launch_limit'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

for dispatch_fixture_pattern in \
    'process_batch_admission_returns_exact_retry_token' \
    'process_batch_admits_a_scheduler_selected_job' \
    'admit_next_process_batch_job(session)' \
    'admit_process_batch_job(session, 1)' \
    'validate_process_batch_dispatch(session, first)' \
    'forged_rejected' \
    'retried.attempt_token == 2'; do
    rg -Fq "$dispatch_fixture_pattern" "$dispatch_fixture"
done

rg -q 'EsProcessBatch::ProcessBatchSession' "$docs"
rg -q 'ES-SCRIPT-033' "$ledger"

printf 'process batch audit: bounded parallel launch, retry, failure, and cancellation are present\n'
