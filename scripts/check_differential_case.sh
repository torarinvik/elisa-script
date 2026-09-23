#!/usr/bin/env bash

# Compiler-free audit for the typed differential case/world boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
source_file="$repo_root/src/testing/differential.elisa"
runner_source="$repo_root/src/ir/runner.elisa"
interpreter_source="$repo_root/src/ir/interpret.elisa"
bytecode_source="$repo_root/src/bytecode/bytecode.elisa"
fixture_file="$repo_root/test/differential/elisascript_differential_test.elisa"
bytecode_fixture_file="$repo_root/test/ir/elisascript_bytecode_test.elisa"
docs_file="$repo_root/docs/differential-testing.md"

for required_file in "$source_file" "$runner_source" "$interpreter_source" "$bytecode_source" "$fixture_file" "$bytecode_fixture_file" "$docs_file"; do
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

for declaration in 'struct DifferentialWorldFile' 'struct DifferentialWorld' 'struct DifferentialWorldSnapshot' 'struct DifferentialWorldSnapshotCheck' 'struct DifferentialWorldMaterializationPlan' 'struct DifferentialWorldMaterializationCheck' 'struct DifferentialCase' 'struct DifferentialComparatorPolicy' 'struct DifferentialArtifactManifest' 'struct DifferentialArtifactManifestDecode' 'struct DifferentialProcessStreamArtifact' 'struct DifferentialProcessStreamArtifactDecode' 'struct DifferentialReproductionArtifact' 'struct DifferentialReproductionArtifactDecode' 'struct DifferentialValuePoolArtifact' 'struct DifferentialValuePoolArtifactDecode' 'struct DifferentialArtifactIndex' 'struct DifferentialArtifactIndexDecode' 'struct DifferentialArtifactReplayCheck' 'struct DifferentialArtifactDirectoryPlan' 'struct DifferentialArtifactDirectoryCheck' 'struct DifferentialShrinkCandidate' 'struct DifferentialShrinkResult' 'struct DifferentialRunShrinkCandidate' 'struct DifferentialRunShrinkResult' 'struct DifferentialOracle' 'struct DifferentialOracleCheck' 'struct DifferentialComparison' 'struct DifferentialComparisonArtifact' 'struct DifferentialComparisonArtifactDecode' 'const enum DifferentialArtifactPolicy' 'const enum DifferentialArtifactPublicationState' 'const enum DifferentialArtifactReplayIssue' 'const enum DifferentialArtifactDirectoryState' 'const enum DifferentialArtifactDirectoryIssue' 'const enum DifferentialShrinkKind' 'const enum DifferentialRunShrinkKind' 'const enum DifferentialOracleLanguage' 'const enum DifferentialOracleIssue' 'const enum DifferentialWorldSnapshotIssue' 'const enum DifferentialWorldMaterializationState' 'const enum DifferentialWorldMaterializationIssue' 'const enum DifferentialCaseSide' 'const enum DifferentialCaseIssueKind' 'const enum DifferentialDifferenceKind' 'const enum DifferentialRunOutcome' 'const enum DifferentialTextComparison' 'const enum DifferentialMapComparison'; do
    if ! rg -q "$declaration" "$source_file"; then
        printf 'differential case audit: missing %s\n' "$declaration" >&2
        exit 1
    fi
done

for helper in differential_case_effective_limit differential_case_runner_with_limits differential_runner_kind_valid prepare_differential_case_runner; do
    if ! rg -q "def $helper\\(" "$source_file"; then
        printf 'differential case audit: missing case limit preparation helper %s\n' "$helper" >&2
        exit 1
    fi
done
rg -q 'case\.timeout_steps == 0 or case\.timeout_steps <= DIFFERENTIAL_DEFAULT_MAX_TIMEOUT_STEPS' "$source_file"
rg -q 'case\.max_output_bytes == 0 or case\.max_output_bytes <= DIFFERENTIAL_DEFAULT_MAX_OUTPUT_BYTES' "$source_file"
rg -q 'runner\.timeout_steps > 0 and runner\.timeout_steps <= DIFFERENTIAL_DEFAULT_MAX_TIMEOUT_STEPS' "$source_file"
rg -q 'DifferentialRunnerIssueKind\.InvalidKind' "$source_file"
rg -q 'invocation\.timeout_steps > DIFFERENTIAL_DEFAULT_MAX_TIMEOUT_STEPS' "$source_file"
rg -q 'timeout_steps: timeout_steps, max_output_bytes: max_output_bytes, required_effects: runner\.required_effects, required_errors: runner\.required_errors' "$source_file"
rg -q 'arguments: runner\.arguments, handlers: runner\.handlers, working_directory: runner\.working_directory, environment: runner\.environment, stdin: runner\.stdin, stdin_bytes: runner\.stdin_bytes, stdin_binary: runner\.stdin_binary, protocol: runner\.protocol' "$source_file"
rg -q 'runner\.max_output_bytes\.usize\(\)' "$source_file"
rg -q 'output_limit: usize = EsIr::ES_RUNTIME_DEFAULT_MAX_OUTPUT_BYTES' "$runner_source"
rg -q 'policy\.output_bytes <- output_limit' "$runner_source"
rg -q 'execute_bytecode_with_resource_policy\(lowered\.module' "$runner_source"
rg -q 'writer\.length > machine\.resource_policy\.output_bytes - machine\.resource_usage\.output_bytes' "$interpreter_source"
rg -q 'output_used: mutable usize&' "$interpreter_source"
rg -q 'runtime_resource_add_output\(machine\.resource_usage, machine\.resource_policy, writer\.offset\)' "$interpreter_source"
rg -q 'process_output_limit: policy\.output_bytes\.u64\(\)' "$interpreter_source"
rg -q 'def process_output_remaining\(' "$interpreter_source"
rg -q 'def process_wait_stream_size\(' "$interpreter_source"
rg -q 'stderr_size > waiter\.output_limit - stdout_size' "$interpreter_source"
rg -q 'output_limit: process_output_remaining\(machine\)' "$interpreter_source"
rg -Uq 'if process_wait_output_exceeded\(waiter\):[\s\S]{0,512}process_wait_terminate\(waiter\)' "$interpreter_source"
rg -q 'write_stdout_value_with_output_ledger\(stdio_text\.text, output_bytes\)' "$bytecode_source"
rg -q 'write_stderr_value_with_output_ledger\(stdio_text\.text, output_bytes\)' "$bytecode_source"
rg -q 'def differential_stream_pair_within_limit\(' "$source_file"
rg -q 'differential_stream_pair_within_limit\(stdout_size, stderr_size, invocation\.max_output_bytes\)' "$source_file"
rg -q 'differential_stream_pair_within_limit\(stdout_size, stderr_size, max_output_bytes\)' "$source_file"

for fixture in differential_case_validation_rejects_limits_above_shared_hard_budgets differential_case_runner_preparation_tightens_both_sides_without_losing_runner_fields differential_case_runner_preparation_inherits_each_sides_runner_limits_when_case_limits_are_zero differential_runner_validation_accepts_every_declared_runner_kind differential_runner_validation_rejects_timeout_above_shared_hard_budget differential_process_execution_rejects_timeout_above_shared_hard_budget_before_launch differential_process_execution_enforces_one_aggregate_output_ceiling differential_elisascript_case_output_ceiling_rejects_before_console_write; do
    if ! rg -q "def $fixture\\(" "$fixture_file"; then
        printf 'differential case audit: missing case limit fixture %s\n' "$fixture" >&2
        exit 1
    fi
done

if ! rg -q 'def bytecode_direct_stdio_rejects_output_before_emission_when_shared_budget_is_full\(' "$bytecode_fixture_file"; then
    printf 'differential case audit: missing bytecode stdio shared-ledger fixture\n' >&2
    exit 1
fi

for helper in differential_world_path_segment_safe differential_world_fixture_path_safe differential_world_issue differential_world_hash_u64 differential_world_hash_text differential_world_fingerprint differential_world_snapshot_valid differential_world_snapshot_failure differential_world_materialization_state_valid differential_world_materialization_root_valid differential_world_materialization_plan_valid differential_world_materialization_failure make_differential_world_snapshot validate_differential_world_snapshot make_differential_world_materialization_plan validate_differential_world_materialization advance_differential_world_materialization differential_artifact_policy_valid differential_engine_requirement_valid differential_float_tolerance_valid differential_comparator_policy_valid differential_text_comparison_byte_valid differential_map_comparison_byte_valid differential_artifact_policy_byte_valid differential_engine_requirement_byte_valid differential_artifact_side_byte_valid differential_run_outcome_byte_valid differential_artifact_publication_state_byte_valid differential_difference_kind_byte_valid differential_execution_engine_byte_valid validate_differential_case make_differential_artifact_manifest differential_manifest_text_bytes_fits differential_artifact_manifest_valid canonical_differential_artifact_manifest_bytes differential_artifact_manifest_fingerprint differential_manifest_read_u64 differential_manifest_read_i64 differential_manifest_read_u32 differential_manifest_read_text_bounds differential_decode_artifact_manifest differential_artifact_manifest_bytes_valid decode_differential_artifact_manifest differential_artifact_side_valid differential_process_stream_artifact_text_bytes_fits differential_process_stream_artifact_valid make_differential_process_stream_artifact canonical_differential_process_stream_artifact_bytes differential_process_stream_artifact_fingerprint differential_decode_process_stream_artifact differential_process_stream_artifact_bytes_valid decode_differential_process_stream_artifact differential_reproduction_text_valid differential_reproduction_artifact_valid make_differential_reproduction_artifact canonical_differential_reproduction_artifact_bytes differential_reproduction_artifact_fingerprint differential_decode_reproduction_artifact differential_reproduction_artifact_bytes_valid decode_differential_reproduction_artifact differential_float_bits differential_float_from_bits differential_value_text_bytes_fits differential_value_record_valid differential_value_text_append_fits differential_value_text_fields_fits differential_value_pool_text_bytes_fits differential_value_pool_artifact_valid differential_emit_value differential_read_value make_differential_value_pool_artifact canonical_differential_value_pool_artifact_bytes differential_value_pool_artifact_fingerprint differential_decode_value_pool_artifact differential_value_pool_artifact_bytes_valid decode_differential_value_pool_artifact differential_artifact_publication_state_valid differential_artifact_index_valid make_differential_artifact_index canonical_differential_artifact_index_bytes differential_artifact_index_fingerprint differential_decode_artifact_index differential_artifact_index_bytes_valid decode_differential_artifact_index differential_artifact_directory_state_valid differential_artifact_directory_component_valid differential_artifact_directory_plan_valid differential_artifact_directory_failure make_differential_artifact_directory_plan validate_differential_artifact_directory advance_differential_artifact_directory differential_artifact_replay_failure validate_differential_artifact_bundle differential_append_shrink_candidate shrink_differential_case differential_run_shrink_input_valid differential_append_run_shrink_candidate shrink_differential_runs differential_oracle_language_valid differential_oracle_runner_independent differential_oracle_failure validate_differential_oracle make_differential_oracle differential_text_length differential_text_equal differential_difference_kind_valid differential_run_outcome_valid differential_process_capture_text_bytes_fit differential_comparison_artifact_text_bytes_fits differential_comparison_artifact_valid make_differential_comparison_artifact canonical_differential_comparison_artifact_bytes differential_comparison_artifact_fingerprint differential_decode_comparison_artifact differential_comparison_artifact_bytes_valid decode_differential_comparison_artifact compare_differential_runs_with_policy compare_differential_runs_with_engine_requirement_policy; do
    if ! rg -q "def $helper\(" "$source_file"; then
        printf 'differential case audit: missing helper %s\n' "$helper" >&2
        exit 1
    fi
done

for helper in differential_run_text_bytes_fits differential_value_pool_comparison_text_bytes_fits differential_capture_observation_values_fit differential_capture_observation_values_shape_valid differential_capture_inputs_text_bytes_fit differential_run_value_text_bytes_fits; do
    if ! rg -q "def $helper\(" "$source_file"; then
        printf 'differential case audit: missing helper %s\n' "$helper" >&2
        exit 1
    fi
done

for helper in differential_map_pair_probes_fit; do
    if ! rg -q "def $helper\(" "$source_file"; then
        printf 'differential case audit: missing map comparison guard %s\n' "$helper" >&2
        exit 1
    fi
done
rg -q 'DIFFERENTIAL_DEFAULT_MAX_MAP_PAIR_PROBES: usize = DIFFERENTIAL_DEFAULT_MAX_COMPARISON_PAIRS / 2' "$source_file"
rg -q 'differential_map_pair_probes_fit\(left\.map_count\.usize\(\), right\.map_count\.usize\(\)\)' "$source_file"

for helper in differential_world_payload_add_fits differential_world_payload_text_fits differential_world_payload_bytes_fits differential_world_payload_fits differential_world_text_field_lengths_valid differential_case_name_valid differential_runner_name_valid differential_oracle_name_valid; do
    if ! rg -q "def $helper\(" "$source_file"; then
        printf 'differential case audit: missing world payload helper %s\n' "$helper" >&2
        exit 1
    fi
done

rg -q 'return false if length == 0 or length > DIFFERENTIAL_DEFAULT_MAX_WORLD_PATH_BYTES' "$source_file"
rg -q 'sview_len\(entry\.name\) > DIFFERENTIAL_DEFAULT_MAX_PROCESS_TEXT_BYTES or sview_len\(entry\.value\) > DIFFERENTIAL_DEFAULT_MAX_PROCESS_TEXT_BYTES' "$source_file"
rg -q 'return false if not differential_manifest_text_bytes_fits\(manifest\)' "$source_file"
rg -q 'return false if total > DIFFERENTIAL_DEFAULT_MAX_WORLD_BYTES' "$source_file"
rg -q 'return false if amount > DIFFERENTIAL_DEFAULT_MAX_WORLD_BYTES - total' "$source_file"
rg -q 'raise DifferentialRunnerError.Invalid if start > DIFFERENTIAL_U32_MAX' "$source_file"
rg -q 'raise DifferentialRunnerError.Invalid if count > DIFFERENTIAL_U32_MAX - start' "$source_file"
rg -q 'raise DifferentialRunnerError.Invalid if pair_count > \(DIFFERENTIAL_U32_MAX - start\) / 2' "$source_file"

for helper in differential_process_text_field_lengths_fit; do
    if ! rg -q "def $helper\(" "$source_file"; then
        printf 'differential case audit: missing process text helper %s\n' "$helper" >&2
        exit 1
    fi
done
rg -q 'return false if arguments\.count > DIFFERENTIAL_DEFAULT_MAX_ARGUMENTS or environment\.count > DIFFERENTIAL_DEFAULT_MAX_ENVIRONMENT_ENTRIES' "$source_file"
rg -q 'Validate, DifferentialRunnerCheckState\.Target if runner\.arguments\.count > DIFFERENTIAL_DEFAULT_MAX_ARGUMENTS' "$source_file"
rg -q 'Validate, DifferentialRunnerCheckState\.Target if runner\.environment\.count > DIFFERENTIAL_DEFAULT_MAX_ENVIRONMENT_ENTRIES' "$source_file"

for boundary in 'differential_world_payload_is_aggregate_bounded' 'oversized_environment' 'oversized_path' 'oversized_name' 'oversized_manifest' 'DIFFERENTIAL_DEFAULT_MAX_WORLD_BYTES' 'DIFFERENTIAL_DEFAULT_MAX_WORLD_PATH_BYTES' 'DIFFERENTIAL_DEFAULT_MAX_WORLD_METADATA_BYTES'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing world payload boundary %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'differential_runner_validation_rejects_oversized_text_before_scan' 'TooMuchProcessText' 'runner process text or working-directory path exceeds its field budget' 'DIFFERENTIAL_DEFAULT_MAX_PROCESS_PATH_BYTES' 'working_directory: sview("x", 0, 4096)'; do
    if ! rg -Fq "$boundary" "$fixture_file" "$source_file"; then
        printf 'differential case audit: missing process text admission coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'validate_differential_runner(case.reference)' 'validate_differential_runner(case.candidate)' 'DifferentialCaseIssueKind.DuplicateWorldPath' 'DifferentialCaseIssueKind.InvalidWorldPath' 'DifferentialCaseIssueKind.InvalidTolerance' 'DifferentialTextComparison.TrimFinalNewline' 'DifferentialMapComparison.Ordered' 'compare_differential_runs_with_policy' 'DifferentialArtifactPolicy.Always' 'DifferentialRunOutcome.Crash' 'DifferentialDifferenceKind.Outcome' 'world_fingerprint' 'format_version: 2' 'format_version: 3' 'DifferentialArtifactSide.Candidate' 'DifferentialArtifactPublicationState.Complete' 'DifferentialArtifactReplayIssue.Incomplete' 'DifferentialArtifactReplayIssue.FingerprintMismatch' 'make_differential_artifact_manifest' 'canonical_differential_artifact_manifest_bytes' 'differential_artifact_manifest_fingerprint' 'decode_differential_artifact_manifest' 'differential_artifact_manifest_bytes_valid' 'make_differential_process_stream_artifact' 'canonical_differential_process_stream_artifact_bytes' 'differential_process_stream_artifact_fingerprint' 'decode_differential_process_stream_artifact' 'differential_process_stream_artifact_bytes_valid' 'make_differential_reproduction_artifact' 'canonical_differential_reproduction_artifact_bytes' 'differential_reproduction_artifact_fingerprint' 'decode_differential_reproduction_artifact' 'differential_reproduction_artifact_bytes_valid' 'make_differential_value_pool_artifact' 'canonical_differential_value_pool_artifact_bytes' 'differential_value_pool_artifact_fingerprint' 'decode_differential_value_pool_artifact' 'differential_value_pool_artifact_bytes_valid' 'make_differential_artifact_index' 'canonical_differential_artifact_index_bytes' 'differential_artifact_index_fingerprint' 'differential_artifact_index_bytes_valid' 'decode_differential_artifact_index' 'make_differential_comparison_artifact' 'canonical_differential_comparison_artifact_bytes' 'differential_comparison_artifact_fingerprint' 'differential_comparison_artifact_bytes_valid' 'decode_differential_comparison_artifact' 'validate_differential_artifact_bundle'; do
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

for boundary in 'unknown_manifest_version' 'unknown_manifest_engine' 'unknown_manifest_policy' 'unknown_manifest_text_policy' 'unknown_manifest_map_policy' 'trailing_manifest'; do
    if ! rg -Fq "$boundary" "$fixture_file"; then
        printf 'differential case audit: missing manifest corruption coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'unknown_version: mutable darray[u8] = encoded' 'decode_differential_comparison_artifact(unknown_version)' 'unknown_comparison_kind' 'unknown_comparison_engine' 'unknown_comparison_outcome' 'trailing: mutable darray[u8] = encoded' 'decode_differential_comparison_artifact(trailing)'; do
    if ! rg -Fq "$boundary" "$fixture_file"; then
        printf 'differential case audit: missing comparison artifact corruption coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'malformed_outcome[22] <- 255' 'malformed_side[21] <- 255' 'malformed_side[21] <- 2' 'malformed_publication[13] <- 255'; do
    if ! rg -Fq "$boundary" "$fixture_file"; then
        printf 'differential case audit: missing serialized enum corruption coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'stdin_bytes: mutable darray[u8]' 'stdin_binary: bool' 'InvalidProcessInputPayload' 'differential_process_preparation_preserves_binary_stdin' 'differential_world_binary_stdin_is_bounded_and_fingerprinted' 'differential_process_capture_text_bytes_fit' 'differential_process_capture_adapter_rejects_oversized_channels' 'DifferentialRunOutcome.OutputLimit'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing binary process-input coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'differential_comparison_rejects_oversized_run_text' 'differential_comparison_rejects_oversized_value_pool_text' 'differential_comparison_rejects_quadratic_unordered_map_probe_budget' 'differential_comparison_rejects_invalid_run_metadata_before_equality' 'differential_run_outcome_valid(reference.outcome)' 'differential_run_outcome_valid(candidate.outcome)' 'differential_engine_metadata_valid(reference)' 'differential_engine_metadata_valid(candidate)' 'reference run outcome is invalid' 'candidate run outcome is invalid' 'reference engine metadata is invalid' 'candidate engine metadata is invalid' 'run text exceeds differential budget' 'owned value text exceeds differential budget' 'differential_process_capture_adapter_rejects_oversized_inputs' 'process capture inputs exceed differential budget' 'differential_process_capture_adapter_rejects_malformed_inputs' 'process capture inputs are structurally invalid' 'differential_runtime_adapter_rejects_oversized_process_snapshots' 'differential_runtime_adapter_rejects_oversized_text_snapshots'; do
    if ! rg -Fq "$boundary" "$fixture_file"; then
        printf 'differential case audit: missing comparison-bound coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'differential_run_outcome_incomplete(reference.outcome)' 'differential_run_outcome_incomplete(candidate.outcome)' 'both runs terminated before producing complete results'; do
    if ! rg -Fq "$boundary" "$source_file"; then
        printf 'differential case audit: missing incomplete-outcome comparison rule %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'timed_out_comparison' 'assert not timed_out_comparison.equal' 'assert timed_out_comparison.kind == DifferentialDifferenceKind.Outcome' 'both_timed_out.status == DifferentialReportStatus.Inconclusive'; do
    if ! rg -Fq "$boundary" "$fixture_file"; then
        printf 'differential case audit: missing paired incomplete-outcome fixture %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'DifferentialArtifactDirectoryState.Staging' 'DifferentialArtifactDirectoryState.Ready' 'DifferentialArtifactDirectoryState.Published' 'DifferentialArtifactDirectoryIssue.InvalidPublicationState' 'DifferentialArtifactDirectoryIssue.InvalidTransition' 'make_differential_artifact_directory_plan' 'validate_differential_artifact_directory' 'advance_differential_artifact_directory'; do
    if ! rg -Fq "$boundary" "$source_file" "$fixture_file"; then
        printf 'differential case audit: missing boundary coverage %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'assert plan.state == DifferentialWorldMaterializationState.Running' 'duplicate_restore: DifferentialWorldMaterializationCheck' 'assert plan.state == DifferentialWorldMaterializationState.Restored' 'assert skipped.state == DifferentialArtifactDirectoryState.Staging' 'duplicate_publish: DifferentialArtifactDirectoryCheck' 'assert published.state == DifferentialArtifactDirectoryState.Published'; do
    if ! rg -Fq "$boundary" "$fixture_file"; then
        printf 'differential case audit: missing terminal state-preservation coverage %s\n' "$boundary" >&2
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

for boundary in 'make_differential_world_snapshot' 'validate_differential_world_snapshot' 'DifferentialWorldSnapshotIssue.FingerprintMismatch' 'def differential_value_kind_byte_valid' 'unknown_value_kind[25] <- 255'; do
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

for fixture in \
    differential_process_execution_captures_native_stdout_and_stderr \
    differential_process_execution_feeds_stdin_without_shell_joining \
    differential_process_execution_applies_environment_only_in_child \
    differential_process_execution_keeps_nonzero_exit_status_as_data \
    differential_process_execution_rejects_invalid_invocation_through_error_channel \
    differential_process_execution_rejects_zero_output_limit_before_launch \
    differential_process_execution_rejects_output_beyond_declared_limit \
    differential_process_execution_rejects_stderr_beyond_declared_limit \
    differential_process_execution_reports_bounded_timeout \
    differential_process_timeout_owns_descendant_process_group; do
    if ! rg -q "def $fixture\(" "$fixture_file"; then
        printf 'differential case audit: missing process execution fixture %s\n' "$fixture" >&2
        exit 1
    fi
done

for boundary in 'if not group_ready:' 'differential_terminate_process(pid, false, status)' 'raise DifferentialRunnerError.Process'; do
    if ! rg -Fq "$boundary" "$source_file"; then
        printf 'differential case audit: missing process-group admission guard %s\n' "$boundary" >&2
        exit 1
    fi
done

for boundary in 'DifferentialWorldMaterializationState.Materializing' 'differential_world_materialization_transition_allowed' 'complete_differential_world_restoration' 'plan.has_materialization_attempt' 'plan.has_reference_restoration' 'plan.has_candidate_restoration' 'plan.reference_restored_world_fingerprint' 'plan.candidate_restored_world_fingerprint'; do
    if ! rg -Fq "$boundary" "$source_file"; then
        printf 'differential case audit: missing verified materialization boundary %s\n' "$boundary" >&2
        exit 1
    fi
done

for fixture_boundary in 'generic_restore: DifferentialWorldMaterializationCheck' 'wrong_restore: DifferentialWorldMaterializationCheck' 'forged_restored: mutable DifferentialWorldMaterializationPlan' 'partial: mutable DifferentialWorldMaterializationPlan'; do
    if ! rg -Fq "$fixture_boundary" "$fixture_file"; then
        printf 'differential case audit: missing restore lifecycle fixture %s\n' "$fixture_boundary" >&2
        exit 1
    fi
done

if ! rg -q 'Define a Case|DifferentialCase|artifact manifest|artifact' "$docs_file"; then
    printf 'differential case audit: documentation omits the case/artifact contract\n' >&2
    exit 1
fi

printf 'differential case audit: typed case, hermetic world, and artifact manifest boundary present\n'
