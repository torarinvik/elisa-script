#!/usr/bin/env bash

# Compiler-free audit for bounded background process supervision.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/process_model.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$fixture" "$docs" "$ledger" "$plan"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'process job audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

for boundary in \
    'const enum ProcessJobState of u8:' \
    'const enum ProcessJobEvent of u8:' \
    'struct ProcessJob:' \
    'error ProcessJobError:' \
    'def advance_process_job(' \
    'ProcessJobError.InvalidState' \
    'ProcessJobError.RetryLimitExceeded' \
    'process_job_state_requires_attempt' \
    'job.attempts > job.max_attempts' \
    'job.state == ProcessJobState.Created and job.attempts >= job.max_attempts' \
    'job.attempts >= job.max_attempts' \
    'ProcessJobState.Cancelled' \
    'ProcessJobEvent.CancelAck'; do
    rg -Fq "$boundary" "$model"
done

for fixture_pattern in \
    'ProcessJobEvent.Timeout' \
    'ProcessJobEvent.Retry' \
    'ProcessJobError.RetryLimitExceeded' \
    'ProcessJobEvent.CancelAck' \
    'forged_cancelled_attempt'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`ProcessJob` and `advance_process_job`' "$docs"
rg -Fq '`ProcessJob` adds a typed background-supervision state machine' "$ledger"
rg -Fq 'P10 process-job follow-up' "$plan"

printf 'process job audit: bounded retry, cancellation, and terminal-state transitions are present\n'
