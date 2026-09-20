#!/usr/bin/env bash

# Compiler-free audit for the typed differential replay lifecycle.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/replay_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"

for required_file in "$model" "$consumer" "$fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'differential replay audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialReplay:' \
    'Limits::RUNS' \
    'const enum DifferentialReplayOrder of u8:' \
    'const enum DifferentialReplayState of u8:' \
    'const enum DifferentialReplayEvent of u8:' \
    'const enum DifferentialReplaySide of u8:' \
    'const enum DifferentialReplayDisposition of u8:' \
    'struct DifferentialReplaySession:' \
    'error DifferentialReplayError:' \
    'def validate_differential_replay_session(' \
    'def differential_replay_expected_side(' \
    'def advance_differential_replay('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'AdmissionMismatch' \
    'MaterializationMismatch' \
    'RunOrderInvalid' \
    'ComparisonNotReady' \
    'RestoreMismatch' \
    'RestorationNotReady' \
    'not session.has_admission and session.admission_fingerprint != 0' \
    'session.admission_fingerprint != session.expected_manifest_fingerprint' \
    'not session.has_reference and session.reference_run_fingerprint != 0' \
    'not session.has_candidate and session.candidate_run_fingerprint != 0' \
    'not session.has_comparison and session.comparison_fingerprint != 0' \
    'not session.has_restoration and session.restored_world_fingerprint != 0' \
    'session.restored_world_fingerprint != session.expected_world_fingerprint' \
    'session.has_materialization_attempt and not session.has_restoration' \
    'session.state == DifferentialReplayState.Restoring and session.disposition == DifferentialReplayDisposition.Normal' \
    'session.state == DifferentialReplayState.Comparing and (session.has_comparison or session.has_restoration)' \
    'DifferentialReplayState.Comparing' \
    'DifferentialReplayState.Restoring'; do
    rg -Fq "$boundary" "$model"
done

for boundary in \
    'ComparisonEvidence' \
    'differential_artifact_comparison_evidence_valid' \
    'comparison sidecar does not describe the process and value-pool evidence' \
    'reference_process.outcome != reference_values.outcome' \
    'candidate_process.exit_status != candidate_values.exit_status' \
    'comparison.reference_outcome != reference_process.outcome' \
    'comparison.reference_value_kind != reference_values.root_value.kind'; do
    rg -Fq "$boundary" "$consumer"
done

rg -Fq 'include "./replay_model.elisa"' "$consumer"
rg -Fq 'using EsDifferentialReplay' "$fixture"
for fixture_pattern in \
    'differential_replay_contract_requires_admission_ordered_runs_and_restoration' \
    'differential_replay_abort_paths_restore_started_worlds_before_terminal_state' \
    'DifferentialReplayEvent.Admit' \
    'DifferentialReplayEvent.CompareComplete' \
    'forged_hidden_replay_fingerprint' \
    'DifferentialReplayEvent.RestoreComplete' \
    'DifferentialReplayError.RunOrderInvalid' \
    'forged_completed_replay' \
    'forged_failed_replay' \
    'forged_cancelled_replay' \
    'forged_admission_identity' \
    'forged_equal_index' \
    'DifferentialArtifactReplayIssue.ComparisonInvalid'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsDifferentialReplay::DifferentialReplaySession' "$docs"

printf 'differential replay audit: bounded admission, ordered side execution, abort cleanup, comparison, and world restoration are present\n'
