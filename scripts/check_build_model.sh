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
target_usage_candidate="$repo_root/test/fixtures/script_parity/target_usage/build.elisascript"
executor_model="$repo_root/src/runtime/build_executor_model.elisa"
executor_fixture="$repo_root/test/runtime/build_executor_test.elisa"
sequential_tools_root="$repo_root/test/fixtures/script_parity/sequential_tools"
sequential_tools_reference="$sequential_tools_root/reference.sh"
sequential_tools_candidate="$sequential_tools_root/candidate.elisascript"
sequential_tools_expected="$sequential_tools_root/expected.txt"
sequential_tools_contract="$sequential_tools_root/CONTRACT.md"
sequential_tools_parity="$repo_root/test/script_parity/sequential_tools_launcher_test.elisascript"
incremental_executor_fixture="$repo_root/test/runtime/build_incremental_executor_test.elisa"
incremental_model="$repo_root/src/runtime/build_incremental_model.elisa"
incremental_posix="$repo_root/src/runtime/build_incremental_posix.elisa"
incremental_posix_executor="$repo_root/src/runtime/build_incremental_posix_executor.elisa"
minimal_native_root="$repo_root/test/fixtures/script_parity/minimal_native_build"
minimal_native_candidate="$minimal_native_root/build.elisascript"
minimal_native_cmake="$minimal_native_root/CMakeLists.txt"
minimal_native_main="$minimal_native_root/src/main.c"
minimal_native_parity="$repo_root/test/script_parity/minimal_native_build_launcher_test.elisascript"
docs="$repo_root/docs/ir.md"

for required_file in "$model" "$ir" "$fixture" "$usage_model" "$usage_fixture" "$target_usage_candidate" "$executor_model" "$executor_fixture" "$sequential_tools_reference" "$sequential_tools_candidate" "$sequential_tools_expected" "$sequential_tools_contract" "$sequential_tools_parity" "$incremental_executor_fixture" "$incremental_model" "$incremental_posix" "$incremental_posix_executor" "$minimal_native_candidate" "$minimal_native_cmake" "$minimal_native_main" "$minimal_native_root/include/generated_build_config.h.in" "$minimal_native_root/include/generated_build_config_variant.h.in" "$minimal_native_parity" "$docs"; do
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
    'SharedLibrary' \
    'const enum BuildUsageKind of u8:' \
    'const enum BuildUsageVisibility of u8:' \
    'const enum BuildUsageLibraryForm of u8:' \
    'struct BuildUsageRequirement:' \
    'library_form: BuildUsageLibraryForm' \
    'struct BuildUsageDependency:' \
    'struct BuildUsageTarget:' \
    'struct BuildUsageTargetResult:' \
    'target_artifact: bool = false' \
    'error BuildUsageError:' \
    'def validate_target_inputs(' \
    'def resolve_build_usage('; do
    rg -Fq "$declaration" "$usage_model"
done

for boundary in \
    'InterfaceVisibilityRequired' \
    'DependencyOrderInvalid' \
    'InvalidDependencyTargetKind' \
    'InvalidLibraryForm' \
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
    'dependency_target.kind == BuildUsageTargetKind.StaticLibrary' \
    'dependency_target.kind == BuildUsageTargetKind.SharedLibrary' \
    'value: dependency_result.name' \
    'target_artifact: true' \
    'library_form_matches_requirement' \
    'if requirement.library_form == BuildUsageLibraryForm.Path:' \
    'not sview_contains_byte(requirement.value, 32)' \
    'left.library_form == right.library_form' \
    'left.target_artifact == right.target_artifact' \
    'target_artifact: entry.target_artifact' \
    'raise BuildUsageError.TotalResolvedLimitExceeded if entries.count' \
    'TOTAL_INPUTS - total_inputs'; do
    rg -Fq "$boundary" "$usage_model"
done
rg -Fq 'ordered_dependencies: darray[usize] = sorted(dependency_indices)' "$usage_model"
rg -Fq 'ordered_target_names: darray[sview] = sorted(target_names)' "$usage_model"
rg -Fq 'for index in 0..<targets.count |targets, total_inputs, target_names|' "$usage_model"
rg -Fq 'for dependency_index in 0..<target.dependencies.count |target, dependency_indices|' "$usage_model"
rg -Fq 'ordered_dependencies[ordered_index - 1] == ordered_dependencies[ordered_index]' "$usage_model"
rg -Fq 'ordered_target_names[name_index - 1] == ordered_target_names[name_index]' "$usage_model"

rg -Fq 'build_usage_public_private_interface_and_static_link_only_propagation' "$usage_fixture"
rg -Fq 'build_usage_shared_dependency_contributes_its_artifact' "$usage_fixture"
rg -Fq 'build_usage_distinguishes_target_artifacts_from_linker_names' "$usage_fixture"
rg -Fq 'build_usage_rejects_mismatched_library_forms' "$usage_fixture"
rg -Fq 'option_as_search_name' "$usage_fixture"
rg -Fq 'whitespace_as_search_name' "$usage_fixture"
rg -Fq 'bare_path_resolution' "$usage_fixture"
rg -Fq 'build_usage_rejects_noncanonical_dependencies_and_interface_visibility' "$usage_fixture"
rg -Fq 'build_usage_private_static_dependency_is_local_and_link_only_exported' "$usage_fixture"
rg -Fq 'static_usage.exported_link[0].library_form == BuildUsageLibraryForm.LinkerArgument' "$usage_fixture"
rg -Fq 'consumer_usage.link[0].value == "static" and consumer_usage.link[0].target_artifact' "$usage_fixture"
rg -Fq 'consumer_usage.link[1].library_form == BuildUsageLibraryForm.LinkerArgument' "$usage_fixture"
rg -Fq 'build_usage_interface_dependency_must_use_interface_visibility' "$usage_fixture"
rg -Fq 'API_LEVEL=3' "$usage_fixture"
rg -Fq 'core_usage.compile.count == 5' "$usage_fixture"
rg -Fq 'include/internal' "$usage_fixture"
rg -Fq 'app_usage.link[2].value == "-Wl,--as-needed"' "$usage_fixture"
rg -Fq 'app_usage.link[0].value == "core"' "$usage_fixture"
rg -Fq 'app_usage.link[3].value == "helper" and not app_usage.link[3].link_only' "$usage_fixture"
rg -Fq 'wrapper_usage.exported_link[0].value == "shared"' "$usage_fixture"
rg -Fq 'assert not app_usage.link[0].target_artifact' "$usage_fixture"
rg -Fq 'assert app_usage.link[1].target_artifact' "$usage_fixture"
rg -Fq 'value == "/opt/fixture/lib/libcustom.a"' "$usage_fixture"
rg -Fq 'value == "deps/lib/librelative.a"' "$usage_fixture"
rg -Fq 'value == "-dash/libspecial.a"' "$usage_fixture"
rg -Fq 'value == "-lcustom"' "$usage_fixture"
rg -Fq 'library_form == BuildUsageLibraryForm.Path' "$usage_fixture"
rg -Fq 'library_form == BuildUsageLibraryForm.LinkerArgument' "$usage_fixture"
rg -Fq 'BuildUsageError.InvalidDependencyTargetKind' "$usage_fixture"
rg -Fq 'if entry.target_artifact:' "$target_usage_candidate"
rg -Fq 'entry.library_form == BuildUsageLibraryForm.Path' "$target_usage_candidate"
rg -Fq 'arguments.push("./" + entry.value)' "$target_usage_candidate"
rg -Fq 'entry.library_form == BuildUsageLibraryForm.LinkerArgument' "$target_usage_candidate"
rg -Fq 'entry.library_form == BuildUsageLibraryForm.SearchName' "$target_usage_candidate"
rg -Fq 'arguments.push("-l" + entry.value)' "$target_usage_candidate"
if rg -n 'BuildUsageRequirement\{kind: BuildUsageKind.LinkLibrary, visibility: BuildUsageVisibility.Private, value: "(core|helper)"\}' "$target_usage_candidate"; then
    printf 'build model audit: target-usage parity candidate masks dependency propagation with an explicit core/helper link requirement\n' >&2
    exit 1
fi

for declaration in \
    'module EsBuildExecutor:' \
    'const enum BuildExecutionFailureKind of u8:' \
    'BuildExecutionFailureKind.Invocation' \
    'BuildExecutionFailureKind.NonzeroExit' \
    'struct BuildExecutionNodeResult:' \
    'struct BuildExecutionResult:' \
    'error BuildExecutionError:' \
    'OutputAlreadyPresent' \
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
rg -Fq 'while offset < command.environment.count |command, environment, offset|' "$executor_model"
rg -Fq 'offset <- offset + 2' "$executor_model"
rg -Fq 'build_executor_first_present_output(output_set)' "$executor_model"

rg -Fq 'build_executor_preflights_supported_process_command_subset' "$executor_fixture"
rg -Fq 'using EsBuild' "$executor_fixture"
rg -Fq 'build_executor_rejects_late_unsupported_command_before_any_launch' "$executor_fixture"
rg -Fq 'executable: "/usr/bin/touch"' "$executor_fixture"
rg -Fq 'environment_mode: ProcessEnvironmentMode.Replace' "$executor_fixture"
rg -Fq 'environment: ["LC_ALL", "C", "TZ", "UTC"]' "$executor_fixture"
rg -Fq 'failure == BuildExecutionError.UnsupportedCommand' "$executor_fixture"
rg -Fq 'marker_absent: bool = not is_file(marker)' "$executor_fixture"
rg -Fq 'graph.state == BuildGraphState.Planned' "$executor_fixture"
rg -Fq 'build_executor_rejects_preexisting_declared_output_before_launch' "$executor_fixture"
rg -Fq 'failure == BuildExecutionError.OutputAlreadyPresent' "$executor_fixture"
rg -Fq 'stale_bytes_preserved' "$executor_fixture"
rg -Fq 'build_executor_nonzero_exit_cancels_dependent_launches' "$executor_fixture"
rg -Fq 'executable: "/usr/bin/false"' "$executor_fixture"
rg -Fq 'BuildExecutionFailureKind.NonzeroExit' "$executor_fixture"
rg -Fq 'BuildNodeState.Cancelled' "$executor_fixture"
rg -Fq 'arguments: ["prepared\n"]' "$executor_fixture"
rg -Fq 'execution.nodes.count == 3 and execution.log_bytes == len("prepared\n")' "$executor_fixture"
rg -Fq 'execution.nodes[0].stdout == "prepared\n"' "$executor_fixture"
rg -Fq 'not execution.nodes[2].started' "$executor_fixture"
rg -Fq 'graph.nodes[2].state == BuildNodeState.Cancelled and marker_absent' "$executor_fixture"
rg -Fq 'sequential_tools_public_launcher_matches_shell_and_golden' "$sequential_tools_parity"
rg -Fq 'ELISASCRIPT_BOUNDED_TEST_RSS_GUARD' "$sequential_tools_parity"
rg -Fq 'return false if candidate_run.exit_status != 0 or candidate_run.stdout != golden' "$sequential_tools_parity"
rg -Fq 'BuildExecutionFailureKind.NonzeroExit' "$sequential_tools_candidate"
rg -Fq 'execution.nodes[2].started or graph.nodes[2].state != BuildNodeState.Cancelled' "$sequential_tools_candidate"
rg -Fq "failure_stdout=\"\$(/usr/bin/false)\"" "$sequential_tools_reference"
rg -Fq 'graph=failed' "$sequential_tools_expected"
rg -Fq 'prepared' "$sequential_tools_expected"
rg -Fq 'A07' "$sequential_tools_contract"
rg -Fq 'graph.state == BuildGraphState.Failed' "$executor_fixture"
rg -Fq 'execute_build_graph_incremental(' "$incremental_executor_fixture"
rg -Fq 'incremental_executor_marks_up_to_date_nodes_as_cache_hits' "$incremental_executor_fixture"
rg -Fq 'commit_build_incremental_execution(result, graph, previous, recipes, observations)' "$incremental_executor_fixture"
rg -Fq 'BuildExecutionError.ExecutionNotSuccessful' "$incremental_executor_fixture"

# Keep the E06 fixture tied to the real CMake/custom-output shape: the
# generated file is declared, and compilation is graph-dependent on it.
rg -Fq 'configure_file(' "$minimal_native_cmake"
rg -Fq 'MINIMAL_BUILD_CONFIG_INPUT' "$minimal_native_cmake"
rg -Fq 'include/generated_build_config.h.in' "$minimal_native_cmake"
rg -Fq 'generated_build_config.h' "$minimal_native_cmake"
rg -Fq 'add_library(minimal-answer STATIC src/answer.c)' "$minimal_native_cmake"
rg -Fq 'target_link_libraries(minimal-native PRIVATE minimal-answer)' "$minimal_native_cmake"
rg -Fq '#include "generated_build_config.h"' "$minimal_native_main"
rg -Fq 'COPY: sview = "/usr/bin/cp"' "$minimal_native_candidate"
rg -Fq 'PARTIAL_FAIL: sview = "/usr/bin/awk"' "$minimal_native_candidate"
rg -Fq 'generator_executable: sview = Toolchain::COPY' "$minimal_native_candidate"
rg -Fq 'generator_arguments: darray[sview] = [generated_header_input_text, generated_header_output_text]' "$minimal_native_candidate"
rg -Fq 'main_compiler_executable: mutable sview = Toolchain::C_COMPILER' "$minimal_native_candidate"
rg -Fq 'main_compiler_arguments <- ["-v", "output=" + main_object_text, "BEGIN { print \"partial-object-created\"; print \"partial\" > output; close(output); exit 1 }"]' "$minimal_native_candidate"
rg -Fq 'executable: generator_executable' "$minimal_native_candidate"
rg -Fq 'arguments: generator_arguments' "$minimal_native_candidate"
rg -Fq '"-I", build_directory_text' "$minimal_native_candidate"
rg -Fq 'executable: Toolchain::ARCHIVER' "$minimal_native_candidate"
rg -Fq 'arguments: ["rcs", static_library_text, answer_object_text]' "$minimal_native_candidate"
rg -Fq 'BuildNode{name: "generate-config-header", command: generate_header_command, dependencies: [], fingerprint: 1u64}' "$minimal_native_candidate"
rg -Fq 'BuildNode{name: "compile-answer", command: compile_answer_command, dependencies: [], fingerprint: 2u64}' "$minimal_native_candidate"
rg -Fq 'BuildNode{name: "archive-answer", command: archive_command, dependencies: [1], fingerprint: 3u64}' "$minimal_native_candidate"
rg -Fq 'BuildNode{name: "compile-main", command: compile_main_command, dependencies: [0], fingerprint: 4u64}' "$minimal_native_candidate"
rg -Fq 'BuildNode{name: Toolchain::TARGET_NAME, command: link_command, dependencies: [2, 3], fingerprint: 5u64}' "$minimal_native_candidate"
rg -Fq 'BuildIncrementalRecipeTarget{name: "compile-main"' "$minimal_native_candidate"
rg -Fq 'dependencies: ["generate-config-header"]' "$minimal_native_candidate"
rg -Fq 'execute_build_graph_incremental_cached_at(arena, lock,' "$minimal_native_candidate"
rg -Fq 'Toolchain::CACHE_LOCK, Toolchain::CACHE_NAME, Toolchain::CACHE_STAGING' "$minimal_native_candidate"
rg -Fq 'program_result: ProcessCapture = try capture_process_result_in_directory(executable(output_path_text), [], "", build_directory,' "$minimal_native_candidate"
rg -Fq 'execution.nodes.count != 5' "$minimal_native_candidate"
rg -Fq 'every_build_node_was_cached(execution)' "$minimal_native_candidate"
rg -Fq 'generated_build_config_variant.h.in' "$minimal_native_candidate"
rg -Fq 'candidate_variant_arguments' "$minimal_native_parity"
rg -Fq 'rebuilt=generate-config-header' "$minimal_native_parity"
rg -Fq 'rebuilt=compile-main' "$minimal_native_parity"
rg -Fq 'rebuilt=minimal-native' "$minimal_native_parity"
rg -Fq 'main.c.o' "$minimal_native_parity"
rg -Fq 'Linking C static library' "$minimal_native_parity"
rg -Fq 'remove_generated_headers' "$minimal_native_parity"
rg -Fq 'reference_missing_output_frontier_matches' "$minimal_native_parity"
rg -Fq 'candidate_missing_output_matches' "$minimal_native_parity"
rg -Fq 'candidate_recovered_noop_matches' "$minimal_native_parity"
rg -Fq 'was not recreated byte-for-byte' "$minimal_native_parity"
rg -Fq 'cmake-reconfigure-minimal-native-missing-output' "$minimal_native_parity"
rg -Fq 'modified_output_rejected' "$minimal_native_parity"
rg -Fq 'modified cached output was not preserved' "$minimal_native_parity"
rg -Fq 'restored_cache_matches' "$minimal_native_parity"
rg -Fq 'partial_compile_arguments' "$minimal_native_parity"
rg -Fq 'compile_failure_matches' "$minimal_native_parity"
rg -Fq 'partial-fail-compile' "$minimal_native_parity"
rg -Fq 'partial-object-created' "$minimal_native_parity"
rg -Fq 'failed graph did not clean started outputs or preserve later unstarted outputs' "$minimal_native_parity"
rg -Fq 'cache_before_failure' "$minimal_native_parity"
rg -Fq 'cache_after_failure' "$minimal_native_parity"
rg -Fq 'failed build replaced the prior cache' "$minimal_native_parity"
rg -Fq 'recover-after-partial-compile-failure' "$minimal_native_parity"
rg -Fq 'noop-after-partial-compile-recovery' "$minimal_native_parity"
rg -Fq 'preserved_binary_run' "$minimal_native_parity"
rg -Fq 'recovered_after_failure' "$minimal_native_parity"
rg -Fq 'OutputInvalidationFingerprintChanged' "$incremental_model"
rg -Fq 'OutputInvalidationOwnershipMissing' "$incremental_model"
rg -Fq 'invalidate_build_incremental_output_at' "$incremental_posix_executor"
rg -Fq 'cleanup_failed_build_graph_outputs_at' "$incremental_posix_executor"
rg -Fq 'continue if not results[node_index].started' "$incremental_posix_executor"
rg -Fq 'require_cached_content: bool' "$incremental_posix_executor"
rg -Fq 'BuildIncrementalFile{path: output_path}, false' "$incremental_posix_executor"
rg -Fq 'cleanup_failed_build_graph_outputs_at(scratch, root_fd, execution.result.nodes, execution.recipes)' "$incremental_posix_executor"
rg -Fq 'exclusive build-root ownership contract' "$incremental_posix_executor"
rg -Fq 'elisascript_posix_unlinkat_leaf' "$incremental_posix_executor"
rg -Fq 'DarwinOpenFlags::NOFOLLOW | DarwinOpenFlags::DIRECTORY' "$incremental_posix_executor"
rg -Fq 'OutputInvalidationError.CachedOutputChanged' "$incremental_posix_executor"
rg -Fq 'OutputInvalidationError.OutputStillPresent' "$incremental_posix_executor"
rg -Fq 'private:' "$incremental_posix_executor"
rg -Fq 'invalidate_dirty_build_target_outputs_at' "$incremental_posix_executor"
rg -Fq 'BuildExecutionError.NodeResultLimitExceeded' "$incremental_posix_executor"
rg -Fq 'build_executor_command_supported(graph.nodes[node_index].command)' "$incremental_posix_executor"
rg -Fq 'execute_build_graph_incremental_serial_at' "$incremental_posix_executor"
rg -Fq 'run_build_command(graph.nodes[node_index].command, effective_limit)' "$incremental_posix_executor"
rg -Fq 'def run_build_command(command: ProcessCommand, output_limit: usize)' "$executor_model"
rg -Fq 'BuildGraphEvent.NodeFailure' "$incremental_posix_executor"
rg -Fq 'BuildGraphEvent.NodeSuccess' "$incremental_posix_executor"
rg -Fq 'corrupt_cached_output_arguments' "$minimal_native_parity"
rg -Fq 'restore_cached_output_arguments' "$minimal_native_parity"
rg -Fq 'def generated_header_artifacts_match(' "$minimal_native_parity"
rg -Fq '"-DCMAKE_AR=/usr/bin/ar"' "$minimal_native_parity"
rg -Fq 'MAX_GENERATED_HEADER_BYTES: usize = 4096' "$minimal_native_parity"
rg -Fq 'is_symlink(template) or is_symlink(cmake_header) or is_symlink(elisa_header)' "$minimal_native_parity"
rg -Fq 'cmake_text == template_text and elisa_text == template_text' "$minimal_native_parity"
rg -Fq 'libminimal-answer.a' "$minimal_native_parity"
rg -Fq 'one or both build routes omitted the expected library or executable' "$minimal_native_parity"

rg -Fq 'BuildContractError.DuplicateDependency' "$fixture"
rg -Fq 'for dependency_position in 0..<node.dependencies.count |node|' "$model"
rg -Fq 'earlier_dependency > dependency_index' "$model"

rg -Fq '`EsBuild` is the shell-replacement boundary' "$docs"
rg -Fq '`EsBuildIncrementalPosixExecutor::execute_build_graph_incremental_cached_at`' "$docs"
rg -Fq 'A host kill or machine crash bypasses in-process cleanup' "$docs"
rg -Fq 'OutputAlreadyPresent' "$docs"

printf 'build model audit: bounded graph, generated-output ordering, usage propagation, serial Process.Run execution, and fail-draining/cancellation are present\n'
