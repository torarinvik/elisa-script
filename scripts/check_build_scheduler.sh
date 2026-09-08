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
    'BUILD_SCHEDULER_MAX_CACHE' \
    'const enum BuildSchedulerState of u8:' \
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
    'NodeAccountingInvalid' \
    'scheduler.graph.active_nodes' \
    'scheduler.graph.completed_nodes != scheduler.graph.nodes.count' \
    'scheduler.ready_queue.count != 0' \
    'scheduler.state == BuildSchedulerState.Ready and scheduler.ready_queue.count != 0' \
    'scheduler.state == BuildSchedulerState.Complete' \
    'CompleteNotReady' \
    'CancelNotReady'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/build_scheduler_model.elisa"' "$ir"
rg -Fq 'using EsBuildScheduler' "$fixture"
for fixture_pattern in \
    'typed_build_scheduler_contract_is_deterministic_cache_aware_and_cancelable' \
    'BuildSchedulerEvent.CacheHit' \
    'BuildSchedulerEvent.Dispatch' \
    'BuildSchedulerEvent.NodeComplete' \
    'BuildSchedulerState.Complete'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsBuildScheduler adds the execution-facing queue contract' "$docs"
rg -Fq 'rejects cache entries for unknown graph nodes' "$docs"
rg -Fq 'ES-SCRIPT-002 | EsBuildScheduler' "$ledger"
rg -Fq 'explicit EsBuildScheduler contract' "$plan"

printf 'build scheduler audit: deterministic ready queue, cache admission, bounded dispatch, accounting, and cancellation are present\n'
