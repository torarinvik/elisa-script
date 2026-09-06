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

for binary_boundary in 'const enum DifferentialWorldFileKind' 'bytes: mutable darray[u8]' 'InvalidWorldFileKind' 'InvalidWorldFilePayload' 'def differential_world_file_kind_valid' 'def differential_world_hash_bytes'; do
    if ! rg -Fq "$binary_boundary" "$source_file"; then
        printf 'differential case audit: missing binary world boundary %s\n' "$binary_boundary" >&2
        exit 1
    fi
done

for binary_helper in differential_world_file_kind_valid differential_world_hash_bytes; do
    if ! rg -q "def $binary_helper\\(" "$source_file"; then
        printf 'differential case audit: missing binary helper %s\n' "$binary_helper" >&2
        exit 1
    fi
done

for declaration in 'struct DifferentialWorldFile' 'struct DifferentialWorld' 'struct DifferentialWorldSnapshot' 'struct DifferentialWorldSnapshotCheck' 'struct DifferentialWorldMaterializationPlan' 'struct DifferentialWorldMaterializationCheck' 'struct DifferentialCase' 'struct DifferentialComparatorPolicy' 'struct DifferentialArtifactManifest' 'struct DifferentialArtifactManifestDecode' 'struct DifferentialProcessStreamArtifact' 'struct DifferentialProcessStreamArtifactDecode' 'struct DifferentialReproductionArtifact' 'struct DifferentialReproductionArtifactDecode' 'struct DifferentialValuePoolArtifact' 'struct DifferentialValuePoolArtifactDecode' 'struct DifferentialArtifactIndex' 'struct DifferentialArtifactIndexDecode' 'struct DifferentialArtifactReplayCheck' 'struct DifferentialArtifactDirectoryPlan' 'struct DifferentialArtifactDirectoryCheck' 'struct DifferentialShrinkCandidate' 'struct DifferentialShrinkResult' 'struct DifferentialRunShrinkCandidate' 'struct DifferentialRunShrinkResult' 'struct DifferentialOracle' 'struct DifferentialOracleCheck' 'struct DifferentialComparison' 'struct DifferentialComparisonArtifact' 'struct DifferentialComparisonArtifactDecode' 'const enum DifferentialArtifactPolicy' 'const enum DifferentialArtifactPublicationState' 'const enum DifferentialArtifactReplayIssue' 'const enum DifferentialArtifactDirectoryState' 'const enum DifferentialArtifactDirectoryIssue' 'const enum DifferentialShrinkKind' 'const enum DifferentialRunShrinkKind' 'const enum DifferentialOracleLanguage' 'const enum DifferentialOracleIssue' 'const enum DifferentialWorldSnapshotIssue' 'const enum DifferentialWorldMaterializationState' 'const enum DifferentialWorldMaterializationIssue' 'const enum DifferentialCaseIssueKind' 'const enum DifferentialDifferenceKind' 'const enum DifferentialRunOutcome' 'const enum DifferentialTextComparison' 'const enum DifferentialMapComparison'; do
    if ! rg -q "$declaration" "$source_file"; then
        printf 'differential case audit: missing %s\n' "$declaration" >&2
        exit 1
    fi
done

for helper in differential_world_path_segment_safe differential_world_fixture_path_safe differential_world_issue differential_world_hash_u64 differential_world_hash_text differential_world_fingerprint differential_world_snapshot_valid differential_world_snapshot_failure differential_world_materialization_state_valid differential_world_materialization_root_valid differential_world_materialization_plan_valid differential_world_materialization_failure make_differential_world_snapshot validate_differential_world_snapshot make_differential_world_materialization_plan validate_differential_world_materialization advance_differential_world_materialization differential_artifact_policy_valid differential_engine_requirement_valid differential_float_tolerance_valid differential_comparator_policy_valid validate_differential_case make_differential_artifact_manifest differential_manifest_text_bytes_fits differential_artifact_manifest_valid canonical_differential_artifact_manifest_bytes differential_artifact_manifest_fingerprint differential_manifest_read_u64 differential_manifest_read_i64 differential_manifest_read_u32 differential_manifest_read_text_bounds differential_decode_artifact_manifest differential_artifact_manifest_bytes_valid decode_differential_artifact_manifest differential_artifact_side_valid differential_process_stream_artifact_text_bytes_fits differential_process_stream_artifact_valid make_differential_process_stream_artifact canonical_differential_process_stream_artifact_bytes differential_process_stream_artifact_fingerprint differential_decode_process_stream_artifact differential_process_stream_artifact_bytes_valid decode_differential_process_stream_artifact differential_reproduction_text_valid differential_reproduction_artifact_valid make_differential_reproduction_artifact canonical_differential_reproduction_artifact_bytes differential_reproduction_artifact_fingerprint differential_decode_reproduction_artifact differential_reproduction_artifact_bytes_valid decode_differential_reproduction_artifact differential_float_bits differential_float_from_bits differential_value_text_bytes_fits differential_value_record_valid differential_value_text_append_fits differential_value_text_fields_fits differential_value_pool_text_bytes_fits differential_value_pool_artifact_valid differential_emit_value differential_read_value make_differential_value_pool_artifact canonical_differential_value_pool_artifact_bytes differential_value_pool_artifact_fingerprint differential_decode_value_pool_artifact differential_value_pool_artifact_bytes_valid decode_differential_value_pool_artifact differential_artifact_publication_state_valid differential_artifact_index_valid make_differential_artifact_index canonical_differential_artifact_index_bytes differential_artifact_index_fingerprint differential_decode_artifact_index differential_artifact_index_bytes_valid decode_differential_artifact_index differential_artifact_directory_state_valid differential_artifact_directory_component_valid differential_artifact_directory_plan_valid differential_artifact_directory_failure make_differential_artifact_directory_plan validate_differential_artifact_directory advance_differential_artifact_directory differential_artifact_replay_failure validate_differential_artifact_bundle differential_append_shrink_candidate shrink_differential_case differential_run_shrink_input_valid differential_append_run_shrink_candidate shrink_differential_runs differential_oracle_language_valid differential_oracle_runner_independent differential_oracle_failure validate_differential_oracle make_differential_oracle differential_text_length differential_text_equal differential_difference_kind_valid differential_run_outcome_valid differential_comparison_artifact_text_bytes_fits differential_comparison_artifact_valid make_differential_comparison_artifact canonical_differential_comparison_artifact_bytes differential_comparison_artifact_fingerprint differential_decode_comparison_artifact differential_comparison_artifact_bytes_valid decode_differential_comparison_artifact compare_differential_runs_with_policy compare_differential_runs_with_engine_requirement_policy; do
    if ! rg -q "def $helper\(" "$source_file"; then
        printf 'differential case audit: missing helper %s\n' "$helper" >&2
        exit 1
    fi
done

for boundary in 'validate_differential_runner(case.reference)' 'validate_differential_runner(case.candidate)' 'DifferentialCaseIssueKind.DuplicateWorldPath' 'DifferentialCaseIssueKind.InvalidWorldPath' 'DifferentialCaseIssueKind.InvalidTolerance' 'DifferentialTextComparison.TrimFinalNewline' 'DifferentialMapComparison.Ordered' 'compare_differential_runs_with_policy' 'DifferentialArtifactPolicy.Always' 'DifferentialRunOutcome.Crash' 'DifferentialDifferenceKind.Outcome' 'world_fingerprint' 'format_version: 2' 'format_version: 3' 'DifferentialArtifactSide.Candidate' 'DifferentialArtifactPublicationState.Complete' 'DifferentialArtifactReplayIssue.Incomplete' 'DifferentialArtifactReplayIssue.FingerprintMismatch' 'make_differential_artifact_manifest' 'canonical_differential_artifact_manifest_bytes' 'differential_artifact_manifest_fingerprint' 'decode_differential_artifact_manifest' 'differential_artifact_manifest_bytes_valid' 'make_differential_process_stream_artifact' 'canonical_differential_process_stream_artifact_bytes' 'differential_process_stream_artifact_fingerprint' 'decode_differential_process_stream_artifact' 'differential_process_stream_artifact_bytes_valid' 'make_differential_reproduction_artifact' 'canonical_differential_reproduction_artifact_bytes' 'differential_reproduction_artifact_fingerprint' 'decode_differential_reproduction_artifact' 'differential_reproduction_artifact_bytes_valid' 'make_differential_value_pool_artifact' 'canonical_differential_value_pool_artifact_bytes' 'differential_value_pool_artifact_fingerprint' 'decode_differential_value_pool_artifact' 'differential_value_pool_artifact_bytes_valid' 'make_differential_artifact_index' 'canonical_differential_artifact_index_bytes' 'differential_artifact_index_fingerprint' 'differential_artifact_index_bytes_valid' 'decode_differential_artifact_index' 'make_differential_comparison_artifact' 'canonical_differential_comparison_artifact_bytes' 'differential_comparison_artifact_fingerprint' 'decode_differential_comparison_artifact' 'differential_comparison_artifact_bytes_valid' 'validate_differential_artifact_bundle'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing boundary coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'DifferentialCaseIssueKind.InvalidWorldFileKind' 'DifferentialCaseIssueKind.InvalidWorldFilePayload' 'DifferentialCaseIssueKind.InvalidWorldStdinPayload' 'DifferentialWorldFileKind.Bytes' 'bytes: [0, 255, 7]' 'changed_binary_case.world.files'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing binary fixture coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'unknown_manifest_version' 'trailing_manifest'; do
    if ! rg -Fq "$boundary" "$fixture_file"; then
        printf 'differential case audit: missing manifest corruption coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'stdin_bytes: mutable darray[u8]' 'stdin_binary: bool' 'InvalidProcessInputPayload' 'differential_process_preparation_preserves_binary_stdin' 'differential_world_binary_stdin_is_bounded_and_fingerprinted'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing binary process-input coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'DifferentialArtifactDirectoryState.Staging' 'DifferentialArtifactDirectoryState.Ready' 'DifferentialArtifactDirectoryState.Published' 'DifferentialArtifactDirectoryIssue.InvalidPublicationState' 'DifferentialArtifactDirectoryIssue.InvalidTransition' 'make_differential_artifact_directory_plan' 'validate_differential_artifact_directory' 'advance_differential_artifact_directory'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing boundary coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'DifferentialShrinkKind.RemoveWorldFile' 'DifferentialShrinkKind.ClearWorldFileBytes' 'DifferentialShrinkKind.RemoveWorldArgument' 'DifferentialShrinkKind.RemoveWorldEnvironment' 'DifferentialShrinkKind.ClearWorldStdin' 'DifferentialShrinkKind.ClearWorldStdinBytes' 'shrink_differential_case'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing boundary coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'DifferentialOracleLanguage.Python' 'DifferentialOracleLanguage.Perl' 'DifferentialOracleLanguage.Awk' 'DifferentialOracleLanguage.Shell' 'DifferentialOracleLanguage.C' 'DifferentialOracleLanguage.Cpp' 'DifferentialOracleIssue.NotIndependent' 'validate_differential_oracle' 'make_differential_oracle'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing boundary coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'make_differential_world_snapshot' 'validate_differential_world_snapshot' 'DifferentialWorldSnapshotIssue.FingerprintMismatch'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing boundary coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'DifferentialWorldMaterializationState.Planned' 'DifferentialWorldMaterializationState.Materialized' 'DifferentialWorldMaterializationState.Running' 'DifferentialWorldMaterializationState.Restoring' 'DifferentialWorldMaterializationState.Restored' 'DifferentialWorldMaterializationIssue.InvalidTransition' 'make_differential_world_materialization_plan' 'validate_differential_world_materialization' 'advance_differential_world_materialization'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing boundary coverage %s\n' "$boundary"
        exit 1
    fi
done

for boundary in 'DifferentialRunShrinkKind.ClearReferenceStdout' 'DifferentialRunShrinkKind.ClearCandidateStdout' 'DifferentialRunShrinkKind.ClearReferenceStderr' 'DifferentialRunShrinkKind.ClearCandidateStderr' 'DifferentialRunShrinkKind.RemoveReferenceObservation' 'DifferentialRunShrinkKind.RemoveCandidateObservation' 'shrink_differential_runs'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing boundary coverage %s\n' "$boundary"
        exit 1
    fi
done

if ! rg -q 'Define a Case|DifferentialCase|artifact manifest|artifact' "$docs_file"; then
    printf 'differential case audit: documentation omits the case/artifact contract\n' >&2
    exit 1
fi

printf 'differential case audit: typed case, hermetic world, and artifact manifest boundary present\n'
