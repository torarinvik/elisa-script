#!/usr/bin/env bash

# Compiler-free audit for the dependency-aware build/process handoff.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/build_batch_model.elisa"
executor="$repo_root/src/runtime/build_executor_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/runtime/build_batch_model_test.elisa"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$executor" "$ir" "$fixture" "$ledger"; do
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
    'def build_batch_session_for_graph_with_outputs(' \
    'def build_batch_output_sets_from_recipes(' \
    'def build_batch_session_for_recipes(' \
    'def build_incremental_batch_session_for_recipes(' \
    'def validate_build_batch_session(' \
    'def begin_build_batch(' \
    'def build_batch_execution_result(' \
    'def dispatch_build_batch_ready(' \
    'def report_build_batch_result(' \
    'def report_build_batch_result_with_outputs(' \
    'def build_batch_process_result_valid(' \
    'def cancel_build_batch(' \
    'def build_batch_stop_acknowledgements_match(' \
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
    'BuildSchedulerEvent.CancelAck' \
    'command_snapshot_bound != result.dispatched' \
    'build_batch_process_commands_equal(result.dispatched_command_snapshot, node.command)' \
    'dispatched_command_snapshot <- node.command' \
    'build_batch_process_succeeded(process_result) and process_result.error_text != ""'; do
    rg -Fq "$invariant" "$model"
done

for incremental_batch_invariant in \
    'ProcessBatchJobState.Skipped' \
    'ProcessBatchEvent.SkipAt' \
    'admit_build_incremental_graph(session.scheduler, previous_targets, recipes, observations)' \
    'result.cache_hit != (job.state == ProcessBatchJobState.Skipped)' \
    'cache_hit_results != session.scheduler.cache_hits' \
    'session.scheduler.cache.count != session.scheduler.cache_hits' \
    'BuildSchedulerEvent.CacheHit'; do
    rg -Fq "$incremental_batch_invariant" "$model"
done

for output_invariant in \
    'build_executor_output_sets_valid(graph, output_sets)' \
    'build_batch_first_missing_output(session.output_sets[dispatch.job_index])' \
    'BuildBatchError.OutputMissing' \
    'session.output_sets.count != 0'; do
    rg -Fq "$output_invariant" "$model"
done

for executor_output_bound in \
    'Limits::OUTPUT_PATHS' \
    'Limits::OUTPUT_PATH_BYTES' \
    'Limits::OUTPUT_INDEX_SLOTS' \
    'def build_executor_output_path_hash(' \
    'slots.reserve(slot_count)'; do
    rg -Fq "$executor_output_bound" "$executor"
done

rg -Fq 'BuildBatchError.StopAcknowledgementMismatch' "$model"

if rg -n 'Process\.Run|elisascript_posix_fork|capture_process_result' "$model"; then
    printf 'build batch audit: host-neutral coordinator must not claim to launch children\n' >&2
    exit 1
fi

for fixture_case in \
    'build_batch_dispatches_ready_nodes_and_refills_capacity' \
    'execution.nodes[0].started and not execution.nodes[0].cache_hit' \
    'execution.nodes[2].stderr == "linked"' \
    'build_batch_failure_cancels_unstarted_nodes_and_drains_siblings' \
    'execution_not_complete_rejected <- failure == BuildBatchError.ExecutionNotComplete' \
    'build_batch_timeout_preserves_partial_diagnostics_and_drains_siblings' \
    'build_batch_accounts_for_multiple_failures_during_drain' \
    'ProcessResultKind.TimedOut' \
    'ProcessResultKind.HostIoFailure' \
    'session.processes.failed == 2 and session.processes.state == ProcessBatchState.Failed' \
    'session.scheduler.graph.log_bytes == len("partial")' \
    'build_batch_cancels_before_begin_without_host_reap' \
    'build_batch_cancellation_waits_for_host_reap_acknowledgement' \
    'build_batch_rejects_omitted_ready_queue_entries' \
    'build_batch_rejects_duplicate_terminal_receipts' \
    'build_batch_rejects_malformed_process_result_without_consuming_reservation' \
    'build_batch_rejects_output_overrun_without_consuming_reservation' \
    'build_batch_rejects_command_mutation_after_dispatch' \
    'mutation_rejected <- failure == BuildBatchError.JobMappingInvalid' \
    'build_batch_rejects_success_receipt_with_host_error_text_atomically' \
    'rejected <- failure == BuildBatchError.ResultInvalid' \
    'parallel_build_launches_receive_only_their_reserved_output_budget' \
    'launches[1].command.capture_output_limit_bytes == 0' \
    'session.results[1].reserved_output_bytes == 0' \
    'build_batch_missing_output_fails_before_dispatching_dependents' \
    'build_batch_maps_recipe_outputs_under_absolute_root' \
    'incremental_build_batch_skips_verified_cache_hits_before_dispatch' \
    'incremental_build_batch_completes_without_launches_when_all_targets_are_cached' \
    'build_batch_execution_result(session)' \
    'commit_build_incremental_execution(execution, session.scheduler.graph, previous, signed.recipes, observations)' \
    'execution.nodes[0].cache_hit and execution.nodes[1].cache_hit' \
    'cancelled_session.scheduler.cache.count == 2 and cancelled_session.scheduler.cache_hits == 0' \
    'cancelled_session.processes.jobs[0].state == ProcessBatchJobState.Cancelled' \
    'cancelled_session.processes.jobs[1].state == ProcessBatchJobState.Cancelled' \
    'cancelled_session.scheduler.cache_hits == 0 and not cancelled_session.results[0].cache_hit' \
    'session.results[0].cache_hit and session.results[1].cache_hit' \
    'incremental_build_batch_invalidates_cached_dependents_of_dirty_inputs' \
    'forged_cache_count_rejected' \
    'forged_unused_cache_rejected' \
    'session.processes.jobs[0].state == ProcessBatchJobState.Skipped' \
    'ProcessBatchState.Succeeded' \
    'session.processes.jobs[0].attempts == 0 and session.scheduler.ready_queue.count == 0' \
    'session.scheduler.cache.count == 0' \
    'launches.count == 1 and launches[0].node_index == 0' \
    'session.processes.jobs[1].state == ProcessBatchJobState.Pending' \
    'dependencies: ["cached-object"]' \
    'session.scheduler.ready_queue.count == 1 and session.scheduler.ready_queue[0] == 1' \
    'launches.count == 1 and launches[0].node_index == 1' \
    'traversal_rejected <- failure == BuildIncrementalError.InvalidPath' \
    'first_wave[0].node_index == 0 and first_wave[1].node_index == 2' \
    'ProcessBatchState.Draining' \
    'incomplete_acknowledgement_rejected' \
    'stale_acknowledgement_rejected' \
    'acknowledge_build_batch_stop(session, stop_requests)'; do
    rg -Fq "$fixture_case" "$fixture"
done

rg -Fq 'ES-SCRIPT-002 | EsBuildScheduler' "$ledger"
rg -Fq 'EsBuildBatch pairs' "$ledger"

printf 'build batch audit: output verification, ready dispatch, receipt correlation, bounded logs, failure drain, and cancellation are present\n'
