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
    'def classify_build_incremental_target('; do
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
    'build_incremental_dependency_declared' \
    'build_incremental_output_owner_index' \
    'producer.outputs' \
    'def plan_build_incremental_cleanup(' \
    'current_recipe_fingerprint != target.recipe_fingerprint' \
    'return try resolve_build_dependencies(node_names, dependency_names)' \
    'EsBuild::Limits::TOTAL_DEPENDENCIES - total_dependencies' \
    'try build_incremental_observations_valid(observations)' \
    'try build_incremental_dependencies_valid(dependencies)'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/build_incremental_model.elisa"' "$ir"
for fixture_check in \
    'typed_build_incremental_contract_distinguishes_noop_and_rebuild_reasons' \
    'resolve_incremental_build_dependencies(manifest)' \
    'attach_build_dependency_resolution(graph, resolution)' \
    'malformed_resolution_rejected' \
    'BuildIncrementalDecision.InputMissing' \
    'BuildIncrementalDecision.OutputChanged' \
    'BuildIncrementalError.DuplicateInput' \
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
