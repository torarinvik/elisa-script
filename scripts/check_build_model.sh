#!/usr/bin/env bash

# Compiler-free audit for typed build/test dependency graphs.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/build_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
usage_model="$repo_root/src/runtime/build_usage_model.elisa"
usage_fixture="$repo_root/test/runtime/build_usage_model_test.elisa"
executor_model="$repo_root/src/runtime/build_executor_model.elisa"
executor_fixture="$repo_root/test/runtime/build_executor_test.elisa"
incremental_executor_fixture="$repo_root/test/runtime/build_incremental_executor_test.elisa"
docs="$repo_root/docs/ir.md"

for required_file in "$model" "$ir" "$fixture" "$usage_model" "$usage_fixture" "$executor_model" "$executor_fixture" "$incremental_executor_fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'build model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsBuild:' \
    'const module Limits:' \
    'Limits::NODES' \
    'Limits::DEPENDENCIES' \
    'Limits::TOTAL_DEPENDENCIES' \
    'Limits::NAME_BYTES' \
    'Limits::LOG_BYTES' \
    'const enum BuildNodeState of u8:' \
    'const enum BuildGraphState of u8:' \
    'BuildGraphState.Failing' \
    'const enum BuildGraphEvent of u8:' \
    'struct BuildNode:' \
    'struct BuildDependencyNames:' \
    'struct BuildNodeNameIndex:' \
    'struct BuildDependencyResolution:' \
    'struct BuildGraph:' \
    'error BuildContractError:' \
    'def validate_build_graph(' \
    'def resolve_build_dependencies(' \
    'def advance_build_graph('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'DependencyOrderInvalid' \
    'DependencyListOrderInvalid' \
    'DependencyShapeInvalid' \
    'NodeNameIndexInvalid' \
    'NodeNameOrderInvalid' \
    'TOTAL_DEPENDENCIES - total_dependencies' \
    'sview_len(name) < Limits::NAME_BYTES' \
    'DuplicateDependency' \
    'MissingDependency' \
    'InvalidParallelism' \
    'DependencyNotReady' \
    'BuildGraphEvent.CacheHit' \
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
rg -Fq 'include "../runtime/build_usage_model.elisa"' "$ir"
rg -Fq 'include "../runtime/build_executor_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_build_dependency_resolution_maps_names_to_canonical_indices' \
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
    'BuildContractError.DependencyOrderInvalid' \
    'BuildContractError.DependencyListOrderInvalid' \
    'BuildContractError.DependencyShapeInvalid'; do
    rg -Fq "$fixture_pattern" "$fixture"
done
rg -Fq 'BuildContractError.DependencyShapeInvalid' "$model"
rg -Fq 'graph.nodes[node_index].name != entry.name' "$model"
rg -Fq 'graph.node_name_order.count != 0 and graph.node_name_order.count != graph.nodes.count' "$model"
rg -Fq 'scheduler.graph.node_name_order.count == scheduler.graph.nodes.count' "$repo_root/src/runtime/build_scheduler_model.elisa"
rg -Fq 'BuildContractError.NodeNameOrderInvalid' "$fixture"
rg -Fq 'BuildContractError.NodeNameIndexInvalid' "$fixture"
rg -Fq 'build_sort_name_indices(node_names, order, scratch)' "$model"
rg -Fq 'build_sort_node_indices(node_dependencies, dependency_scratch)' "$model"

for declaration in \
    'module EsBuildUsage:' \
    'const module Limits:' \
    'TOTAL_INPUTS' \
    'TOTAL_RESOLVED_ENTRIES' \
    'const enum BuildUsageTargetKind of u8:' \
    'const enum BuildUsageKind of u8:' \
    'const enum BuildUsageVisibility of u8:' \
    'struct BuildUsageRequirement:' \
    'struct BuildUsageDependency:' \
    'struct BuildUsageTarget:' \
    'struct BuildUsageTargetResult:' \
    'error BuildUsageError:' \
    'def validate_target_inputs(' \
    'def resolve_build_usage('; do
    rg -Fq "$declaration" "$usage_model"
done

for boundary in \
    'InterfaceVisibilityRequired' \
    'DependencyOrderInvalid' \
    'DuplicateDependency' \
    'BuildUsageTargetKind.StaticLibrary' \
    'BuildUsageVisibility.Public' \
    'BuildUsageVisibility.Interface' \
    'dependency.target_index' \
    'dependency.visibility != BuildUsageVisibility.Private' \
    'target.kind == BuildUsageTargetKind.StaticLibrary' \
    'link_only: true' \
    'dependency_result.exported_compile' \
    'dependency_result.exported_link' \
    'TOTAL_INPUTS - total_inputs'; do
    rg -Fq "$boundary" "$usage_model"
done

rg -Fq 'build_usage_public_private_interface_and_static_link_only_propagation' "$usage_fixture"
rg -Fq 'build_usage_rejects_noncanonical_dependencies_and_interface_visibility' "$usage_fixture"
rg -Fq 'build_usage_private_static_dependency_is_local_and_link_only_exported' "$usage_fixture"
rg -Fq 'build_usage_interface_dependency_must_use_interface_visibility' "$usage_fixture"

for declaration in \
    'module EsBuildExecutor:' \
    'const enum BuildExecutionFailureKind of u8:' \
    'BuildExecutionFailureKind.Invocation' \
    'BuildExecutionFailureKind.NonzeroExit' \
    'struct BuildExecutionNodeResult:' \
    'struct BuildExecutionResult:' \
    'error BuildExecutionError:' \
    'def build_executor_command_supported_impl(' \
    'def execute_build_command(' \
    'def execute_build_graph_serial('; do
    rg -Fq "$declaration" "$executor_model"
done

for boundary in \
    'ProcessEnvironmentMode.Inherit' \
    'ProcessStdioMode.Null' \
    'ProcessStdioMode.Capture' \
    'command.timeout_micros == 0' \
    'Preflight every command that will execute before the first' \
    'def execute_build_graph_incremental(' \
    'def commit_build_incremental_execution(' \
    'ExecutionNotSuccessful' \
    'ExecutionResultMismatch' \
    'build_executor_incremental_execution_result_matches(' \
    'BuildGraphEvent.CacheHit' \
    'BuildGraphEvent.NodeFailure' \
    'LOG_BYTES - graph.log_bytes'; do
    rg -Fq "$boundary" "$executor_model"
done

rg -Fq 'build_executor_preflights_supported_process_command_subset' "$executor_fixture"
rg -Fq 'using EsBuild' "$executor_fixture"
rg -Fq 'build_executor_rejects_late_unsupported_command_before_any_launch' "$executor_fixture"
rg -Fq 'executable: "/usr/bin/touch"' "$executor_fixture"
rg -Fq 'environment_mode: ProcessEnvironmentMode.Replace' "$executor_fixture"
rg -Fq 'failure == BuildExecutionError.UnsupportedCommand' "$executor_fixture"
rg -Fq 'marker_absent: bool = not is_file(marker)' "$executor_fixture"
rg -Fq 'graph.state == BuildGraphState.Planned' "$executor_fixture"
rg -Fq 'build_executor_nonzero_exit_cancels_dependent_launches' "$executor_fixture"
rg -Fq 'executable: "/usr/bin/false"' "$executor_fixture"
rg -Fq 'BuildExecutionFailureKind.NonzeroExit' "$executor_fixture"
rg -Fq 'BuildNodeState.Cancelled' "$executor_fixture"
rg -Fq 'not execution.nodes[1].started' "$executor_fixture"
rg -Fq 'graph.state == BuildGraphState.Failed' "$executor_fixture"
rg -Fq 'execute_build_graph_incremental(' "$incremental_executor_fixture"
rg -Fq 'incremental_executor_marks_up_to_date_nodes_as_cache_hits' "$incremental_executor_fixture"
rg -Fq 'commit_build_incremental_execution(result, graph, previous, recipes, observations)' "$incremental_executor_fixture"
rg -Fq 'BuildExecutionError.ExecutionNotSuccessful' "$incremental_executor_fixture"

rg -Fq 'BuildContractError.DuplicateDependency' "$fixture"
rg -Fq 'for dependency_position in 0..<node.dependencies.count |node|' "$model"
rg -Fq 'earlier_dependency > dependency_index' "$model"

rg -Fq '`EsBuild` is the shell-replacement boundary' "$docs"

printf 'build model audit: bounded graph, usage propagation, serial Process.Run execution, and fail-draining/cancellation are present\n'
