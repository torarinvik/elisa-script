#!/usr/bin/env bash

# Compiler-free audit for deterministic build scheduling.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/build_scheduler_model.elisa"
build_model="$repo_root/src/runtime/build_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$build_model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
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
    'def advance_build_scheduler(' \
    'def scheduler_rebuild_ready('; do
    rg -Fq "$declaration" "$model"
done

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
    'scheduler.state == BuildSchedulerState.Complete' \
    'scheduler.state == BuildSchedulerState.Failed' \
    'CompleteNotReady' \
    'CancelNotReady' \
    'scheduler.graph.state == BuildGraphState.Succeeded'; do
    rg -Fq "$boundary" "$model"
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
    'BuildSchedulerState.Complete' \
    'completed_cancel_rejected'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsBuildScheduler adds the execution-facing queue contract' "$docs"
rg -Fq 'cache entries for unknown graph nodes' "$docs"
rg -Fq 'ES-SCRIPT-002 | EsBuildScheduler' "$ledger"
rg -Fq 'explicit EsBuildScheduler contract' "$plan"

printf 'build scheduler audit: deterministic queue, fail-draining, cache admission, bounded dispatch, and cancellation are present\n'
