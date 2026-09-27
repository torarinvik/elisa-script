#!/usr/bin/env bash

# Compiler-free audit for pure incremental-build decisions.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/build_incremental_model.elisa"
cache_model="$repo_root/src/runtime/build_incremental_cache_model.elisa"
build_model="$repo_root/src/runtime/build_model.elisa"
executor_model="$repo_root/src/runtime/build_executor_model.elisa"
graph_model="$repo_root/src/runtime/build_incremental_graph_model.elisa"
posix_executor="$repo_root/src/runtime/build_incremental_posix_executor.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
transition_fixture="$repo_root/test/runtime/build_incremental_transition_test.elisa"
posix_fixture="$repo_root/test/runtime/build_incremental_posix_test.elisa"
posix_executor_fixture="$repo_root/test/runtime/build_incremental_posix_executor_test.elisa"
recipe_signature="$repo_root/src/runtime/build_recipe_signature.elisa"
recipe_signature_fixture="$repo_root/test/runtime/build_recipe_signature_test.elisa"
cache_fixture="$repo_root/test/runtime/build_incremental_cache_test.elisa"
cache_adapter_fixture="$repo_root/test/runtime/build_incremental_cache_adapter_test.elisa"
executor_fixture="$repo_root/test/runtime/build_incremental_executor_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$cache_model" "$build_model" "$executor_model" "$graph_model" "$posix_executor" "$ir" "$fixture" "$transition_fixture" "$posix_fixture" "$posix_executor_fixture" "$recipe_signature" "$recipe_signature_fixture" "$cache_fixture" "$cache_adapter_fixture" "$executor_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'incremental build audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for cache_declaration in \
    'module EsBuildIncrementalCache:' \
    'CACHE_BYTES: usize' \
    'FORMAT_VERSION: u8 = 3' \
    'def encode_build_incremental_cache(' \
    'def decode_build_incremental_cache(' \
    'BuildIncrementalCacheError.ChecksumMismatch' \
    'payload_end: usize = bytes.count - Limits::CHECKSUM_BYTES' \
    'validate_build_incremental_signed_manifest(targets)'; do
    rg -Fq "$cache_declaration" "$cache_model"
done

rg -Fq 'def attach_build_dependency_resolution(' "$build_model"
rg -Fq 'resolution.dependencies[node_index]' "$build_model"

for declaration in \
    'module EsBuildIncremental:' \
    'const module Limits:' \
    'Limits::TARGETS' \
    'Limits::INPUTS' \
    'Limits::OUTPUTS' \
    'Limits::OBSERVATIONS' \
    'Limits::CLEANUP_OUTPUTS' \
    'Limits::TOTAL_INPUTS' \
    'Limits::TOTAL_OUTPUTS' \
    'const enum BuildIncrementalTargetKind of u8:' \
    'Phony' \
    'const enum BuildIncrementalDecision of u8:' \
    'struct BuildIncrementalTarget:' \
    'struct BuildIncrementalRecipeTarget:' \
    'struct BuildIncrementalPlan:' \
    'struct BuildIncrementalCommit:' \
    'struct BuildIncrementalResolvedManifest:' \
    'struct BuildIncrementalStaleOutput:' \
    'struct BuildIncrementalObservation:' \
    'ObservationSetMismatch' \
    'error BuildIncrementalError:' \
    'len(name) < Limits::NAME_BYTES' \
    'len(path) < Limits::PATH_BYTES' \
    'def validate_build_incremental_manifest(' \
    'def resolve_incremental_build_dependencies(' \
    'def build_incremental_manifest_resolution(' \
    'def build_incremental_dependency_resolution(' \
    'def build_incremental_path_owners(' \
    'def build_sort_incremental_path_owners(' \
    'def classify_build_incremental_target(' \
    'def classify_build_incremental_manifest(' \
    'def build_incremental_find_target_index(' \
    'def build_incremental_recipe_shape_matches(' \
    'def build_incremental_materialize_recipe_targets(' \
    'def plan_build_incremental_transition(' \
    'target_names: darray[sview]' \
    'recipe_fingerprints: darray[u64]' \
    'def build_incremental_observed_commit_file(' \
    'def build_incremental_observations_match_paths(' \
    'def validate_build_incremental_stable_sources(' \
    'def commit_build_incremental_success(' \
    'def build_incremental_target_decision_validated(' \
    'def build_incremental_target_valid(target)' \
    'def build_incremental_dependency_order(' \
    'def build_incremental_dependency_observation_position(' \
    'def build_incremental_observation_order(' \
    'def build_sort_incremental_observation_indices('; do
    rg -Fq "$declaration" "$model"
done

rg -Fq 'def plan_build_incremental_graph_transition(' "$graph_model"
rg -Fq 'def validate_build_incremental_graph_signatures(' "$graph_model"
rg -Fq 'build_recipe_signatures_for_actions(commands, recipes, toolchains)' "$graph_model"
rg -Fq 'def execute_build_graph_incremental_at(' "$posix_executor"
rg -Fq 'def commit_build_incremental_execution_at(' "$posix_executor"
rg -Fq 'def execute_build_graph_incremental_cached_at(' "$posix_executor"
rg -Fq 'admit_build_incremental_cache_at_held(scratch, lock, cache_directory_fd, lock_name, owner_token, cache_name)' "$posix_executor"
rg -Fq 'publish_build_incremental_cache_at_held(scratch, lock, cache_directory_fd, lock_name, owner_token, staging_name, cache_name, prepared.cache_bytes)' "$posix_executor"
rg -Fq 'cache_unchanged: bool = false' "$posix_executor"
rg -Fq 'cache_unchanged: publication.unchanged' "$posix_executor"
rg -Fq 'def artifact_cache_writer_lock_matches_at(' "$repo_root/src/ir/artifact_cache.elisa"
rg -Fq 'elisascript_posix_flock(lock.descriptor, PosixLockOperations::EXCLUSIVE + PosixLockOperations::NONBLOCK)' "$repo_root/src/ir/artifact_cache.elisa"
rg -Fq 'def admit_build_incremental_cache_at_held(' "$repo_root/src/ir/artifact_cache.elisa"
rg -Fq 'manifest_bytes: darray[u8]' "$repo_root/src/ir/artifact_cache.elisa"
rg -Fq 'manifest_bytes: bytes, previous_targets: targets' "$repo_root/src/ir/artifact_cache.elisa"
rg -Fq 'def publish_build_incremental_cache_at_held(' "$repo_root/src/ir/artifact_cache.elisa"
rg -Fq 'ToolchainObservationError.ToolchainChanged' "$posix_executor"
rg -Fq 'validate_build_incremental_stable_sources(execution.recipes, execution.pre_execution_observations, observations)' "$posix_executor"
rg -Fq 'BuildIncrementalPosixExecution{result: result, recipes: signed.recipes, pre_execution_observations: observations}' "$posix_executor"
rg -Fq 'def validate_build_recipe_toolchain_paths(' "$posix_executor"
rg -Fq 'ToolchainObservationError.ToolchainCommandMismatch' "$posix_executor"
rg -Fq 'ToolchainObservationError.InvalidToolchainPath' "$posix_executor"
rg -Fq 'toolchain_resolution_must_match_graph_command_before_observation' "$posix_executor_fixture"
rg -Fq 'ToolchainObservationError.InvalidToolchainPath(0)' "$posix_executor_fixture"
rg -Fq 'stable_source_validation_rejects_mid_build_changes' "$posix_executor_fixture"
rg -Fq 'generated_change_allowed' "$posix_executor_fixture"
rg -Fq 'graph.state != BuildGraphState.Planned' "$graph_model"
rg -Fq 'def sign_build_incremental_graph(' "$recipe_signature"
rg -Fq 'def build_recipe_signatures_for_actions(' "$recipe_signature"
rg -Fq 'toolchain_identity: BuildRecipeToolchainIdentity' "$model"
rg -Fq 'def admit_build_incremental_graph(' "$repo_root/src/runtime/build_scheduler_model.elisa"
if rg -Fq 'def admit_build_incremental_plan(' "$repo_root/src/runtime/build_scheduler_model.elisa"; then
    printf 'incremental build audit: unsafe caller-supplied plan admission is public\n' >&2
    exit 1
fi

rg -Fq 'def execute_build_graph_incremental(' "$executor_model"
rg -Fq 'def commit_build_incremental_execution(' "$executor_model"
rg -Fq 'def build_incremental_observation_paths(' "$model"
rg -Fq 'def validate_build_incremental_signed_manifest(' "$model"
rg -Fq 'segment_length == 2 and sview_at(path, segment_start) == 46' "$model"
rg -Fq 'build_incremental_manifest_rejects_unsafe_relative_paths' "$transition_fixture"
rg -Fq 'def open_build_incremental_file_at(' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'def observe_build_incremental_file_at(' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'def build_incremental_opened_file_identity_matches(' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'catch open_build_incremental_file_at(root_fd, path):' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'named_path_matches <- build_incremental_opened_file_identity_matches(opened, named_file)' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'not stable or not named_path_matches' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'def observe_build_recipe_toolchain_identity_at(' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'word3: observation.fingerprint_word3' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'def observe_build_incremental_recipes_at(' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'arena_rewind(scratch, mark)' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'def canonical_bytes_sha256_word(' "$repo_root/src/ir/serialize.elisa"
rg -Fq 'schedule: mutable u64[64] = zeroed' "$repo_root/src/ir/serialize.elisa"
rg -Fq 'constants: u64[64] = [' "$repo_root/src/ir/serialize.elisa"
rg -Fq 'canonical_bytes_sha256_word(bytes, 3)' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'incremental_file_fingerprint_uses_complete_canonical_sha256' "$posix_fixture"
rg -Fq 'fingerprint_word3' "$cache_model"
rg -Fq 'DarwinOpenFlags::NOFOLLOW' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'include "../runtime/build_incremental_posix.elisa"' "$ir"
rg -Fq 'incremental_file_open_rejects_invalid_capability_and_paths' "$posix_fixture"
rg -Fq 'observe_build_recipe_toolchain_identity_at(scratch, -1, "usr/bin/compiler")' "$posix_fixture"
rg -Fq 'include "../runtime/build_incremental_cache_model.elisa"' "$ir"
rg -Fq 'include "../runtime/build_recipe_signature.elisa"' "$ir"
rg -Fq 'include "../runtime/build_incremental_graph_model.elisa"' "$ir"
rg -Fq 'include "../runtime/build_incremental_posix_executor.elisa"' "$ir"
rg -Fq 'def build_recipe_signature(' "$recipe_signature"
rg -Fq 'EsIr::canonical_bytes_sha256_word(bytes, 3)' "$recipe_signature"
for signature_input in \
    'toolchain.word3' \
    'command.executable' \
    'command.arguments' \
    'command.working_directory' \
    'command.environment_mode' \
    'command.environment' \
    'command.stdin_mode' \
    'command.stdin_path' \
    'command.stdout_mode' \
    'command.stdout_path' \
    'command.stderr_mode' \
    'command.stderr_path' \
    'command.timeout_micros' \
    'command.capture_output_limit_bytes' \
    'command.failure_mode' \
    'recipe.inputs' \
    'recipe.outputs' \
    'recipe.dependencies'; do
    rg -Fq "$signature_input" "$recipe_signature"
done
for signature_policy in \
    'InheritedEnvironmentUncacheable if command.environment_mode == ProcessEnvironmentMode.Inherit' \
    'AmbientExecutableUncacheable if not path_is_absolute(path(command.executable))' \
    'WorkingDirectoryUncacheable if command.working_directory == "" or not path_is_absolute(path(command.working_directory))' \
    'StdioPolicyUncacheable if command.stdin_mode != ProcessStdioMode.Null or command.stdout_mode != ProcessStdioMode.Capture or command.stderr_mode != ProcessStdioMode.Capture' \
    'StdioPolicyUncacheable if command.stdin_path != "" or command.stdout_path != "" or command.stderr_path != ""' \
    'FailurePolicyUncacheable if command.failure_mode != ProcessFailureMode.Check' \
    'UnboundedExecutionUncacheable if command.timeout_micros == 0'; do
    rg -Fq "$signature_policy" "$recipe_signature"
done
for recipe_signature_check in \
    'build_recipe_signature_binds_command_target_and_toolchain' \
    'AmbientExecutableUncacheable' \
    'InheritedEnvironmentUncacheable' \
    'WorkingDirectoryUncacheable' \
    'StdioPolicyUncacheable' \
    'FailurePolicyUncacheable' \
    'UnboundedExecutionUncacheable' \
    'sign_build_incremental_recipe' \
    'split_arguments' \
    'changed_command' \
    'changed_recipe' \
    'changed_toolchain' \
    'relative_executable_rejected' \
    'relative_working_directory_rejected' \
    'empty_working_directory_rejected' \
    'inherited_stdin_rejected' \
    'unbounded_execution_rejected' \
    'permissive_failure_rejected' \
    'uncaptured_output_rejected' \
    'file_redirect_rejected'; do
    rg -Fq "$recipe_signature_check" "$recipe_signature_fixture"
done

for cache_fixture_check in \
    'incremental_cache_codec_round_trips_a_valid_manifest' \
    'incremental_cache_codec_rejects_checksum_corruption' \
    'incremental_cache_codec_rejects_scalar_recipe_v2_records' \
    'incremental_cache_codec_rejects_unsigned_recipe_manifests' \
    'decode_build_incremental_cache(encoded)' \
    'BuildIncrementalCacheError.ChecksumMismatch'; do
    rg -Fq "$cache_fixture_check" "$cache_fixture"
done

for cache_adapter_check in \
    'incremental_cache_descriptor_io_rejects_invalid_directory_handles' \
    'publish_build_incremental_cache_at_held(arena, unrelated_lock' \
    'read_build_incremental_cache_at_held(arena, unrelated_lock' \
    'held_publish_rejected' \
    'held_read_rejected'; do
    rg -Fq "$cache_adapter_check" "$cache_adapter_fixture"
done

for executor_check in \
    'incremental_executor_marks_up_to_date_nodes_as_cache_hits' \
    'command_mismatch_rejected' \
    'BuildIncrementalObservation{path: "build/app", present: false}' \
    'missing_output_rejected' \
    'BuildIncrementalError.CommitOutputMissing' \
    'commit_build_incremental_execution(result, graph, previous, recipes, observations)' \
    'execute_build_graph_incremental(graph, previous, recipes, observations)' \
    'cache_hit and not result.nodes[0].started'; do
    rg -Fq "$executor_check" "$executor_fixture"
done
rg -Fq 'signature_mismatch_rejected' "$repo_root/test/runtime/build_incremental_scheduler_test.elisa"

for boundary in \
    'BuildIncrementalDecision.UpToDate' \
    'build_incremental_transition_rebuilds_on_signature_change_without_scalar_change' \
    'BuildIncrementalDecision.RecipeChanged' \
    'BuildIncrementalDecision.DependencyDirty' \
    'BuildIncrementalDecision.InputChanged' \
    'BuildIncrementalDecision.OutputMissing' \
    'BuildIncrementalTargetKind.Phony' \
    'BuildIncrementalError.DuplicateInput' \
    'BuildIncrementalError.DuplicateOutput' \
    'BuildIncrementalError.OutputForbidden' \
    'BuildIncrementalError.OutputCollision' \
    'BuildIncrementalError.InputOutputCollision' \
    'BuildIncrementalError.UndeclaredOutputDependency' \
    'BuildIncrementalError.OrphanedOutputInput' \
    'BuildIncrementalError.CleanupOutputLimitExceeded' \
    'BuildIncrementalError.DependencyOrderInvalid' \
    'BuildIncrementalError.CurrentRecipeShapeInvalid' \
    'BuildIncrementalError.TotalInputLimitExceeded' \
    'BuildIncrementalError.TotalOutputLimitExceeded' \
    'BuildIncrementalError.DependencyResolutionInvalid' \
    'BuildIncrementalError.InvalidDependencyObservation' \
    'BuildContractError.DuplicateNode' \
    'BuildContractError.DuplicateDependency' \
    'build_incremental_target_shape_valid(target)' \
    'BuildIncrementalPathOrder' \
    'build_incremental_path_order' \
    'build_incremental_observation_index(observations, sorted_observation_indices, input.path)' \
    'build_incremental_dependency_index_contains' \
    'build_incremental_dependency_index_contains(resolution.dependencies[input_owner.target_index], output_target_index)' \
    'build_incremental_path_owner_position' \
    'build_incremental_path_owner_position(input_owners, output.path)' \
    'build_incremental_path_owner_order' \
    'build_sort_incremental_path_owners(dependency_owners, dependency_scratch)' \
    'Limits::TOTAL_INPUTS - owners.count' \
    'Limits::TOTAL_OUTPUTS - owners.count' \
    'BuildIncrementalError.DuplicateInput if previous.path == current.path and previous.target_index == current.target_index' \
    'build_incremental_path_owner_position(current_manifest.output_owners, output.path)' \
    'build_incremental_path_owner_position(current_manifest.input_owners, output.path)' \
    'current_manifest <- try build_incremental_manifest_resolution(current_targets)' \
    'def plan_build_incremental_cleanup(' \
    'current_recipe_fingerprint != target.recipe_fingerprint' \
    'build_incremental_observation_order(observations)' \
    'decisions[dependency_index] == BuildIncrementalDecision.UpToDate' \
    'build_sort_incremental_path_owners(owners, scratch)' \
    'build_incremental_dependency_observation_position(dependency_order, dependency)'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/build_incremental_model.elisa"' "$ir"
for fixture_check in \
    'typed_build_incremental_contract_distinguishes_noop_and_rebuild_reasons' \
    'resolve_incremental_build_dependencies(manifest)' \
    'classify_build_incremental_manifest(manifest, changed_recipes, build_observations)' \
    'BuildIncrementalDecision.DependencyDirty' \
    'duplicate_observation_rejected' \
    'attach_build_dependency_resolution(graph, resolution)' \
    'malformed_resolution_rejected' \
    'BuildIncrementalDecision.InputMissing' \
    'BuildIncrementalDecision.OutputChanged' \
    'BuildIncrementalError.DuplicateInput' \
    'BuildIncrementalError.DuplicateOutput' \
    'BuildIncrementalError.DuplicateTarget' \
    'BuildIncrementalError.DuplicateDependency' \
    'duplicate_output_rejected' \
    'duplicate_target_rejected' \
    'duplicate_dependency_rejected' \
    'BuildIncrementalError.OutputForbidden' \
    'BuildIncrementalError.OutputCollision' \
    'BuildIncrementalError.UndeclaredOutputDependency' \
    'plan_build_incremental_cleanup' \
    'BuildIncrementalError.OrphanedOutputInput' \
    'BuildIncrementalError.DependencyOrderInvalid'; do
    rg -Fq "$fixture_check" "$fixture"
done

for transition_check in \
    'build_incremental_generated_header_changes_rebuild_only_its_w07_dependents' \
    'build_incremental_distinguishes_missing_and_changed_generated_outputs' \
    'build_incremental_transition_rebuilds_changed_and_new_targets' \
    'build_incremental_observation_paths_are_unique_and_sorted' \
    'build_incremental_observation_paths(recipes)' \
    'BuildIncrementalError.ObservationSetMismatch' \
    'build_incremental_transition_plans_removed_outputs_only_after_success' \
    'build_incremental_success_commit_is_complete_and_atomic' \
    'plan_build_incremental_transition(previous, current, observations)' \
    'commit_build_incremental_success(previous, current, complete_observations)' \
    'BuildIncrementalDecision.RecipeChanged' \
    'BuildIncrementalDecision.DependencyDirty' \
    'BuildIncrementalDecision.OutputChanged' \
    'BuildIncrementalDecision.OutputMissing' \
    'BuildIncrementalDecision.UpToDate' \
    'build/libminimal-answer.a' \
    'changed_header.rebuild_target_indices == [0, 3, 4, 5]' \
    'missing_header.rebuild_target_indices == [0, 3, 4, 5]' \
    'BuildIncrementalError.ObservationSetMismatch' \
    'stale_outputs_after_success'; do
    rg -Fq "$transition_check" "$transition_fixture"
done

rg -Fq '`EsBuildIncremental` is the pure CMake/Ninja-style stale-decision boundary' "$docs"
rg -Fq '`EsBuildIncremental` adds the bounded pure manifest boundary' "$ledger"

printf 'incremental build audit: bounded cached-to-current recipe transitions and post-success cleanup plans are present\n'
