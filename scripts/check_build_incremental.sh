#!/usr/bin/env bash

# Compiler-free audit for pure incremental-build decisions.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/build_incremental_model.elisa"
build_model="$repo_root/src/runtime/build_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$build_model" "$ir" "$fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'incremental build audit: missing %s\n' "$required_file" >&2; exit 1; }
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
    'struct BuildIncrementalStaleOutput:' \
    'struct BuildIncrementalObservation:' \
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
    'def build_incremental_target_decision_validated(' \
    'def build_incremental_observation_order(' \
    'def build_sort_incremental_observation_indices('; do
    rg -Fq "$declaration" "$model"
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
    'BuildContractError.DuplicateNode' \
    'BuildContractError.DuplicateDependency' \
    'build_incremental_target_shape_valid(target)' \
    'BuildIncrementalPathOrder' \
    'build_incremental_path_order' \
    'build_incremental_observation_index(observations, sorted_observation_indices, input.path)' \
    'build_incremental_dependency_index_contains' \
    'build_incremental_dependency_index_contains(resolution.dependencies[input_owner.target_index], output_target_index)' \
    'build_incremental_path_owner_position' \
    'build_incremental_path_owner_order' \
    'Limits::TOTAL_INPUTS - owners.count' \
    'Limits::TOTAL_OUTPUTS - owners.count' \
    'BuildIncrementalError.DuplicateInput if previous.path == current.path and previous.target_index == current.target_index' \
    'build_incremental_output_owner_index' \
    'def plan_build_incremental_cleanup(' \
    'current_recipe_fingerprint != target.recipe_fingerprint' \
    'build_incremental_observation_order(observations)' \
    'decisions[dependency_index] == BuildIncrementalDecision.UpToDate' \
    'try build_incremental_dependencies_valid(dependencies)'; do
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

rg -Fq '`EsBuildIncremental` is the pure CMake/Ninja-style stale-decision boundary' "$docs"
rg -Fq '`EsBuildIncremental` adds the bounded pure manifest boundary' "$ledger"

printf 'incremental build audit: bounded recipe/input/output decisions and dependency ordering are present\n'
