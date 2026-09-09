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
    'BUILD_MAX_NODES' \
    'const enum BuildNodeState of u8:' \
    'const enum BuildGraphState of u8:' \
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
    'FailureNotReady' \
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
    'active_graph' \
    'BuildContractError.DependencyOrderInvalid'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsBuild` is the shell-replacement boundary' "$docs"
rg -Fq 'P10 build-graph follow-up' "$plan"

printf 'build model audit: deterministic dependency ordering, bounded parallelism/logs, and cancellation are present\n'
