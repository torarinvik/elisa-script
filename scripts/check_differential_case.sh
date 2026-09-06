#!/usr/bin/env bash

# Compiler-free audit for the typed differential case/world boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
source_file="$repo_root/src/testing/differential.elisa"
fixture_file="$repo_root/test/differential/elisascript_differential_test.elisa"
docs_file="$repo_root/docs/differential-testing.md"

for required_file in "$source_file" "$fixture_file" "$docs_file"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'differential case audit: missing file: %s\n' "$required_file" >&2
        exit 2
    fi
done

for declaration in 'struct DifferentialWorldFile' 'struct DifferentialWorld' 'struct DifferentialCase' 'struct DifferentialArtifactManifest' 'const enum DifferentialArtifactPolicy' 'const enum DifferentialCaseIssueKind'; do
    if ! rg -q "$declaration" "$source_file"; then
        printf 'differential case audit: missing %s\n' "$declaration" >&2
        exit 1
    fi
done

for helper in differential_world_issue differential_artifact_policy_valid differential_engine_requirement_valid validate_differential_case make_differential_artifact_manifest differential_manifest_text_bytes_fits differential_artifact_manifest_valid canonical_differential_artifact_manifest_bytes differential_artifact_manifest_fingerprint; do
    if ! rg -q "def $helper\(" "$source_file"; then
        printf 'differential case audit: missing helper %s\n' "$helper" >&2
        exit 1
    fi
done

for boundary in 'validate_differential_runner(case.reference)' 'validate_differential_runner(case.candidate)' 'DifferentialCaseIssueKind.DuplicateWorldPath' 'DifferentialArtifactPolicy.Always' 'make_differential_artifact_manifest' 'canonical_differential_artifact_manifest_bytes' 'differential_artifact_manifest_fingerprint'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing boundary coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

if ! rg -q 'Define a Case|DifferentialCase|artifact manifest|artifact' "$docs_file"; then
    printf 'differential case audit: documentation omits the case/artifact contract\n' >&2
    exit 1
fi

printf 'differential case audit: typed case, hermetic world, and artifact manifest boundary present\n'
