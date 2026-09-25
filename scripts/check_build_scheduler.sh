#!/usr/bin/env bash

# Compiler-free audit for deterministic build scheduling.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/build_scheduler_model.elisa"
build_model="$repo_root/src/runtime/build_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
incremental_fixture="$repo_root/test/runtime/build_incremental_scheduler_test.elisa"
incremental_graph_model="$repo_root/src/runtime/build_incremental_graph_model.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$build_model" "$incremental_graph_model" "$ir" "$fixture" "$incremental_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'build scheduler audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsBuildScheduler:' \
    'const module Limits:' \
    'Limits::CACHE_ENTRIES' \
    'EsBuild::Limits::NODES' \
    'const enum BuildSchedulerState of u8:' \
    'BuildSchedulerState.Failing' \
    'const enum BuildSchedulerEvent of u8:' \
    'struct BuildCacheEntry:' \
    'struct BuildScheduler:' \
    'error BuildSchedulerError:' \
    'def validate_build_scheduler(' \
    'def admit_build_incremental_graph(' \
    'IncrementalPlanInvalid' \
    'IncrementalPlanMismatch' \
    'def advance_build_scheduler(' \
    'def scheduler_rebuild_ready('; do
    rg -Fq "$declaration" "$model"
done
if rg -Fq 'def admit_build_incremental_plan(' "$model"; then
    printf 'build scheduler audit: hand-constructed plans remain publicly admissible\n' >&2
    exit 1
fi

for integration_check in \
    'using EsBuildIncremental' \
    'using EsBuildIncrementalGraph' \
    'plan.decisions.count != scheduler.graph.nodes.count' \
    'plan.target_names[index] != scheduler.graph.nodes[index].name' \
    'plan.recipe_fingerprints[index] != scheduler.graph.nodes[index].fingerprint' \
    'plan.decisions[target_index] == BuildIncrementalDecision.UpToDate' \
    'scheduler.cache <- admitted_cache'; do
    rg -Fq "$integration_check" "$model"
done
rg -Fq 'plan_build_incremental_graph_transition(previous_targets, scheduler.graph, current_recipes, observations)' "$model"
rg -Fq 'middle: usize = low + (high - low) / 2' "$model"
rg -Fq 'if node.state == BuildNodeState.Planned:' "$model"
rg -Fq 'raise BuildSchedulerError.DuplicateQueueEntry if previous == queued' "$model"
rg -Fq 'raise BuildSchedulerError.QueueOrderInvalid if previous > queued' "$model"

for boundary in \
    'scheduler_dependency_ready' \
    'scheduler_cache_matches' \
    'scheduler_rebuild_ready' \
    'CacheMiss' \
    'CacheEntryInvalid' \
    'DependencyNotReady' \
    'ActiveLimitExceeded' \
    'BuildGraphState.Failing' \
    'BuildSchedulerState.Failing' \
    'failure_in_progress' \
    'ack_failure' \
    'NodeAccountingInvalid' \
    'scheduler.completed_nodes > scheduler.graph.nodes.count' \
    'scheduler.cache_hits > scheduler.completed_nodes' \
    'scheduler.graph.active_nodes' \
    'scheduler.graph.completed_nodes != scheduler.graph.nodes.count' \
    'scheduler.graph.nodes[index].state == BuildNodeState.Running' \
    'scheduler.active_nodes <- scheduler.active_nodes - 1' \
    'scheduler.ready_queue.count != 0' \
    'scheduler.state == BuildSchedulerState.Ready and scheduler.ready_queue.count != 0' \
    'QueueOrderInvalid' \
    'scheduler.ready_queue[index - 1] > queued' \
    'scheduler.state == BuildSchedulerState.Complete' \
    'scheduler.state == BuildSchedulerState.Failed' \
    'CompleteNotReady' \
    'CancelNotReady' \
    'scheduler.state == BuildSchedulerState.Ready' \
    'scheduler.state <- BuildSchedulerState.Cancelled' \
    'scheduler.graph.state == BuildGraphState.Succeeded'; do
    rg -Fq "$boundary" "$model"
done

for incremental_fixture_check in \
    'graph_aligned_incremental_plan_reaches_scheduler' \
    'admit_build_incremental_graph(scheduler, previous, recipes, observations)' \
    'signature_mismatch_rejected' \
    'BuildIncrementalError.CurrentRecipeShapeInvalid'; do
    rg -Fq "$incremental_fixture_check" "$incremental_fixture"
done

rg -Fq 'include "../runtime/build_scheduler_model.elisa"' "$ir"
rg -Fq 'using EsBuildScheduler' "$fixture"
for fixture_pattern in \
    'typed_build_scheduler_contract_is_deterministic_cache_aware_and_cancelable' \
    'BuildSchedulerEvent.CacheHit' \
    'BuildSchedulerEvent.Dispatch' \
    'BuildSchedulerEvent.NodeComplete' \
    'BuildSchedulerEvent.NodeFail' \
    'BuildSchedulerState.Failing' \
    'BuildSchedulerEvent.CancelAck' \
    'active_cancel' \
    'dispatch_after_failure' \
    'cache_after_failure' \
    'completed_during_drain' \
    'forged_cancelling_failure' \
    'planned_cancel_scheduler' \
    'failed_during_drain' \
    'forged_queue_order' \
    'BuildSchedulerState.Complete' \
    'completed_cancel_rejected'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

for queue_fixture_pattern in \
    'build_scheduler_uses_ordered_queue_membership_and_rejects_duplicates' \
    'advance_build_scheduler(scheduler, BuildSchedulerEvent.Dispatch, 2)' \
    'duplicate_scheduler.ready_queue <- [0, 0]' \
    'BuildSchedulerError.DuplicateQueueEntry'; do
    rg -Fq "$queue_fixture_pattern" "$incremental_fixture"
done

rg -Fq 'EsBuildScheduler adds the execution-facing queue contract' "$docs"
rg -Fq 'cache entries for unknown graph nodes' "$docs"
rg -Fq 'ES-SCRIPT-002 | EsBuildScheduler' "$ledger"

printf 'build scheduler audit: deterministic queue, fail-draining, cache admission, bounded dispatch, and cancellation are present\n'
