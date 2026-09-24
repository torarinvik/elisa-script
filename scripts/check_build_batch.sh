#!/usr/bin/env bash

# Compiler-free audit for the dependency-aware build/process handoff.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/build_batch_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/runtime/build_batch_model_test.elisa"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'build batch audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -Fq 'module EsBuildBatch:' "$model"
rg -Fq 'include "../runtime/build_batch_model.elisa"' "$ir"
for declaration in \
    'struct BuildBatchLaunch:' \
    'struct BuildBatchNodeResult:' \
    'struct BuildBatchSession:' \
    'error BuildBatchError:' \
    'def build_batch_session_for_graph(' \
    'def validate_build_batch_session(' \
    'def begin_build_batch(' \
    'def dispatch_build_batch_ready(' \
    'def report_build_batch_result(' \
    'def build_batch_process_result_valid(' \
    'def cancel_build_batch(' \
    'def acknowledge_build_batch_stop('; do
    rg -Fq "$declaration" "$model"
done

for invariant in \
    'BuildSchedulerEvent.Dispatch' \
    'admit_process_batch_job(session.processes, node_index)' \
    'validate_process_batch_dispatch(session.processes, dispatch)' \
    'ProcessBatchEvent.Fail' \
    'ProcessBatchEvent.ReapAck' \
    'BuildSchedulerEvent.NodeFail' \
    'session.reserved_output_bytes' \
    'EsBuild::Limits::LOG_BYTES' \
    'BuildSchedulerState.Failing' \
    'expected_ready != session.scheduler.ready_queue.count' \
    'ProcessBatchState.Draining' \
    'ProcessBatchEvent.CancelAck' \
    'BuildSchedulerEvent.CancelAck'; do
    rg -Fq "$invariant" "$model"
done

if rg -n 'Process\.Run|elisascript_posix_fork|capture_process_result' "$model"; then
    printf 'build batch audit: host-neutral coordinator must not claim to launch children\n' >&2
    exit 1
fi

for fixture_case in \
    'build_batch_dispatches_ready_nodes_and_refills_capacity' \
    'build_batch_failure_cancels_unstarted_nodes_and_drains_siblings' \
    'build_batch_cancellation_waits_for_host_reap_acknowledgement' \
    'build_batch_rejects_omitted_ready_queue_entries' \
    'build_batch_rejects_duplicate_terminal_receipts' \
    'build_batch_rejects_malformed_process_result_without_consuming_reservation' \
    'build_batch_rejects_output_overrun_without_consuming_reservation' \
    'first_wave[0].node_index == 0 and first_wave[1].node_index == 2' \
    'ProcessBatchState.Draining' \
    'acknowledge_build_batch_stop(session)'; do
    rg -Fq "$fixture_case" "$fixture"
done

rg -Fq 'ES-SCRIPT-002 | EsBuildScheduler' "$ledger"
rg -Fq 'EsBuildBatch pairs' "$ledger"

printf 'build batch audit: ready dispatch, receipt correlation, bounded logs, failure drain, and cancellation are present\n'
