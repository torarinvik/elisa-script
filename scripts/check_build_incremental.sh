#!/usr/bin/env bash

# Compiler-free audit for pure incremental-build decisions.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/build_incremental_model.elisa"
cache_model="$repo_root/src/runtime/build_incremental_cache_model.elisa"
build_model="$repo_root/src/runtime/build_model.elisa"
executor_model="$repo_root/src/runtime/build_executor_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
transition_fixture="$repo_root/test/runtime/build_incremental_transition_test.elisa"
posix_fixture="$repo_root/test/runtime/build_incremental_posix_test.elisa"
cache_fixture="$repo_root/test/runtime/build_incremental_cache_test.elisa"
executor_fixture="$repo_root/test/runtime/build_incremental_executor_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$cache_model" "$build_model" "$executor_model" "$ir" "$fixture" "$transition_fixture" "$posix_fixture" "$cache_fixture" "$executor_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'incremental build audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for cache_declaration in \
    'module EsBuildIncrementalCache:' \
    'CACHE_BYTES: usize' \
    'FORMAT_VERSION: u8' \
    'def encode_build_incremental_cache(' \
    'def decode_build_incremental_cache(' \
    'BuildIncrementalCacheError.ChecksumMismatch' \
    'payload_end: usize = bytes.count - Limits::CHECKSUM_BYTES' \
    'validate_build_incremental_manifest(targets)'; do
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
    'def plan_build_incremental_graph_transition(' \
    'graph.state != BuildGraphState.Planned' \
    'node.fingerprint != recipe.recipe_fingerprint' \
    'target_names: darray[sview]' \
    'recipe_fingerprints: darray[u64]' \
    'def build_incremental_observed_commit_file(' \
    'def build_incremental_observations_match_paths(' \
    'def commit_build_incremental_success(' \
    'def build_incremental_target_decision_validated(' \
    'def build_incremental_target_valid(target)' \
    'def build_incremental_dependency_order(' \
    'def build_incremental_dependency_observation_position(' \
    'def build_incremental_observation_order(' \
    'def build_sort_incremental_observation_indices('; do
    rg -Fq "$declaration" "$model"
done

rg -Fq 'def execute_build_graph_incremental(' "$executor_model"
rg -Fq 'def commit_build_incremental_execution(' "$executor_model"
rg -Fq 'def build_incremental_observation_paths(' "$model"
rg -Fq 'segment_length == 2 and sview_at(path, segment_start) == 46' "$model"
rg -Fq 'build_incremental_manifest_rejects_unsafe_relative_paths' "$transition_fixture"
rg -Fq 'def open_build_incremental_file_at(' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'def observe_build_incremental_file_at(' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'def observe_build_incremental_recipes_at(' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'arena_rewind(scratch, mark)' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'def canonical_bytes_sha256_word(' "$repo_root/src/ir/serialize.elisa"
rg -Fq 'schedule: mutable u64[64] = zeroed' "$repo_root/src/ir/serialize.elisa"
rg -Fq 'constants: u64[64] = [' "$repo_root/src/ir/serialize.elisa"
rg -Fq 'incremental_file_fingerprint_uses_canonical_sha256_word' "$posix_fixture"
rg -Fq 'DarwinOpenFlags::NOFOLLOW' "$repo_root/src/runtime/build_incremental_posix.elisa"
rg -Fq 'include "../runtime/build_incremental_posix.elisa"' "$ir"
rg -Fq 'incremental_file_open_rejects_invalid_capability_and_paths' "$posix_fixture"
rg -Fq 'include "../runtime/build_incremental_cache_model.elisa"' "$ir"

for cache_fixture_check in \
    'incremental_cache_codec_round_trips_a_valid_manifest' \
    'incremental_cache_codec_rejects_checksum_corruption' \
    'decode_build_incremental_cache(encoded)' \
    'BuildIncrementalCacheError.ChecksumMismatch'; do
    rg -Fq "$cache_fixture_check" "$cache_fixture"
done

for executor_check in \
    'incremental_executor_marks_up_to_date_nodes_as_cache_hits' \
    'commit_build_incremental_execution(result, graph, previous, recipes, observations)' \
    'execute_build_graph_incremental(graph, previous, recipes, observations)' \
    'cache_hit and not result.nodes[0].started'; do
    rg -Fq "$executor_check" "$executor_fixture"
done

for boundary in \
    'BuildIncrementalDecision.UpToDate' \
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
    'BuildIncrementalError.ObservationSetMismatch' \
    'stale_outputs_after_success'; do
    rg -Fq "$transition_check" "$transition_fixture"
done

rg -Fq '`EsBuildIncremental` is the pure CMake/Ninja-style stale-decision boundary' "$docs"
rg -Fq '`EsBuildIncremental` adds the bounded pure manifest boundary' "$ledger"

printf 'incremental build audit: bounded cached-to-current recipe transitions and post-success cleanup plans are present\n'
