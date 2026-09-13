#!/usr/bin/env bash

# Compiler-free audit for typed build/test dependency graphs.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/build_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'build model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsBuild:' \
    'const module Limits:' \
    'Limits::NODES' \
    'Limits::DEPENDENCIES' \
    'Limits::LOG_BYTES' \
    'const enum BuildNodeState of u8:' \
    'const enum BuildGraphState of u8:' \
    'BuildGraphState.Failing' \
    'const enum BuildGraphEvent of u8:' \
    'struct BuildNode:' \
    'struct BuildGraph:' \
    'error BuildContractError:' \
    'def validate_build_graph(' \
    'def advance_build_graph('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'DependencyOrderInvalid' \
    'MissingDependency' \
    'InvalidParallelism' \
    'DependencyNotReady' \
    'FingerprintMissing' \
    'LogLimitExceeded' \
    'total_log_bytes > Limits::LOG_BYTES' \
    'node.log_bytes > Limits::LOG_BYTES - total_log_bytes' \
    'planned_nodes' \
    'graph.failed_nodes == 0 or graph.active_nodes == 0 or planned_nodes != 0' \
    'failure_in_progress' \
    'ack_failure' \
    'cancelled_nodes' \
    'graph.failed_nodes != 0 or cancelled_nodes != 0 or graph.completed_nodes >= graph.nodes.count' \
    'graph.active_nodes != 0 or graph.completed_nodes != graph.nodes.count or graph.failed_nodes != 0 or cancelled_nodes == 0' \
    'graph.failed_nodes != 0 or cancelled_nodes == 0' \
    'or cancelled_nodes != 0' \
    'CancelNotReady' \
    'terminal_nodes' \
    'graph.state == BuildGraphState.Succeeded' \
    'graph.completed_nodes != graph.nodes.count' \
    'graph.active_nodes != 0' \
    'graph.nodes[index].state == BuildNodeState.Running' \
    'graph.active_nodes <- graph.active_nodes - 1' \
    'validate_process_command'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/build_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_build_graph_contract_is_ordered_bounded_and_cancelable' \
    'BuildGraphEvent.NodeStart' \
    'BuildGraphEvent.NodeFailure' \
    'BuildGraphState.Failing' \
    'BuildGraphEvent.CancelAck' \
    'active_graph' \
    'forged_cancelling_failure' \
    'forged_cancelling_complete' \
    'forged_cancelling_cancelled' \
    'forged_cancelled_success' \
    'forged_all_success_cancelled_state' \
    'graph_success_during_drain' \
    'cancel_after_failure' \
    'BuildContractError.DependencyOrderInvalid'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsBuild` is the shell-replacement boundary' "$docs"
rg -Fq 'P10 build-graph follow-up' "$plan"

printf 'build model audit: deterministic dependencies, bounded parallelism/logs, and fail-draining/cancellation are present\n'
