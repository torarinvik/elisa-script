#!/usr/bin/env bash

# Compiler-free audit for bounded parallel process-batch scheduling.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/process_batch_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'process batch audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsProcessBatch:' "$model"
rg -q 'include "\.\./runtime/process_batch_model\.elisa"' "$ir"
for declaration in \
    'const enum ProcessBatchFailureMode of u8' \
    'const enum ProcessBatchState of u8' \
    'const enum ProcessBatchJobState of u8' \
    'const enum ProcessBatchEvent of u8' \
    'struct ProcessBatchPolicy:' \
    'struct ProcessBatchJob:' \
    'struct ProcessBatchSession:' \
    'error ProcessBatchError:' \
    'def validate_process_batch\(' \
    'def advance_process_batch\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'PROCESS_BATCH_MAX_JOBS' \
    'PROCESS_BATCH_MAX_PARALLEL' \
    'PROCESS_BATCH_MAX_ATTEMPTS' \
    'process_batch_pending_index' \
    'process_batch_all_terminal' \
    'ProcessBatchFailureMode.FailFast' \
    'ProcessBatchFailureMode.Aggregate' \
    'ProcessBatchEvent.Retry' \
    'ProcessBatchEvent.CancelAck' \
    'ProcessBatchError.ParallelLimitExceeded' \
    'ProcessBatchError.DuplicateJobId' \
    'ProcessBatchError.RetryNotReady' \
    'ProcessBatchState.Planned and' \
    'ProcessBatchState.Succeeded and' \
    'ProcessBatchState.Cancelled and'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsProcessBatch' \
    'typed_process_batch_contract_bounds_parallel_retry_and_cancel' \
    'ProcessBatchEvent.Launch' \
    'ProcessBatchEvent.Retry' \
    'ProcessBatchEvent.CancelAck' \
    'ProcessBatchError.DuplicateJobId' \
    'ProcessBatchError.AccountingInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsProcessBatch::ProcessBatchSession' "$docs"
rg -q 'ES-SCRIPT-033' "$ledger"
rg -q 'P10 process-batch follow-up' "$plan"

printf 'process batch audit: bounded parallel launch, retry, failure, and cancellation are present\n'
