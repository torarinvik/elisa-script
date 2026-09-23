#!/usr/bin/env bash

# Compiler-free audit for typed differential report output.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/report_model.elisa"
renderer="$repo_root/src/testing/report_render_model.elisa"
transport="$repo_root/src/testing/report_transport_model.elisa"
transport_posix="$repo_root/src/testing/report_transport_posix.elisa"
adapter="$repo_root/src/testing/report_adapter_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"

for required_file in "$model" "$renderer" "$transport" "$transport_posix" "$adapter" "$consumer" "$fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'differential report audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for adapter_boundary in \
    'module EsDifferentialReportAdapter:' \
    'DifferentialReportAdapterError' \
    'report_adapter_difference_kind_valid' \
    'report_adapter_run_outcome_valid' \
    'report_adapter_run_outcome_incomplete' \
    'report_adapter_comparison_kind' \
    'report_adapter_category' \
    'report_adapter_project_comparison' \
    'def make_differential_report(' \
    'def make_differential_case_replay_report(' \
    'def record_differential_case_replay_stability_observation(' \
    'def make_differential_case_stability_report(' \
    'ReplayEvidenceMismatch' \
    'StabilityEvidenceMismatch' \
    'DifferentialReportStatus.Passed' \
    'DifferentialReportCategory.ValueMismatch' \
    'DifferentialReportCategory.ObservationMismatch' \
    'DifferentialReportCategory.Timeout' \
    'DifferentialReportStatus.Inconclusive' \
    'DifferentialRunOutcome.OutputLimit' \
    'validate_differential_report(report)'; do
    rg -Fq "$adapter_boundary" "$adapter"
done

for transport_posix_boundary in \
    'module EsDifferentialReportTransportPosix:' \
    'MAX_EINTR_RETRIES: usize = 8' \
    'MAX_WRITE_CALLS: usize = 1048576' \
    'write_differential_report_transport_fd(' \
    'elisascript_posix_write' \
    'DarwinErrno::EINTR' \
    'WriteCallLimitExceeded' \
    'DifferentialReportTransportEvent.Fail'; do
    rg -Fq "$transport_posix_boundary" "$transport_posix"
done

for renderer_boundary in \
    'module EsDifferentialReportRender:' \
    'const module Limits:' \
    'MAX_BYTES: usize = 33554432' \
    'def render_differential_report_json(' \
    'def render_differential_report_human(' \
    'def render_differential_report_junit(' \
    'def render_differential_report(' \
    'validate_differential_report(report)' \
    'report.format != DifferentialReportFormat.Json' \
    'report.format != DifferentialReportFormat.Human' \
    'report.format != DifferentialReportFormat.Junit' \
    'report_render_xml_fields_valid(report)' \
    'XmlCharacterInvalid' \
    'report_render_junit_failure_count' \
    'report_render_junit_error_count' \
    'report_render_junit_skipped_count' \
    'DifferentialReportStatus.Inconclusive' \
    'DifferentialReportCategory.Flaky' \
    'report_render_append_xml_escaped' \
    'OutputLimitExceeded' \
    'report_render_append_json_string' \
    'report_render_append_stability' \
    'baseline_reference_fingerprint' \
    'comparison_fingerprint' \
    'report.messages.count'; do
    rg -Fq "$renderer_boundary" "$renderer"
done

for transport_boundary in \
    'module EsDifferentialReportTransport:' \
    'MAX_CHUNK_BYTES: usize = 1048576' \
    'DifferentialReportTransportState' \
    'DifferentialReportTransportEvent' \
    'begin_differential_report_transport(' \
    'validate_differential_report_transport(' \
    'peek_differential_report_chunk(' \
    'advance_differential_report_transport(' \
    'ShortWrite' \
    'CancelAck'; do
    rg -Fq "$transport_boundary" "$transport"
done

for declaration in \
    'module EsDifferentialReport:' \
    'using EsDifferentialStability' \
    'Limits::TEXT_BYTES' \
    'Limits::TOTAL_TEXT_BYTES' \
    'Limits::MESSAGES' \
    'Limits::REPEATS' \
    'const enum DifferentialReportFormat of u8:' \
    'const enum DifferentialReportStatus of u8:' \
    'const enum DifferentialReportCategory of u8:' \
    'struct DifferentialReport:' \
    'stability_evidence: DifferentialStabilitySession' \
    'error DifferentialReportError:' \
    'def validate_differential_report('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'differential_report_format_valid' \
    'differential_report_status_valid' \
    'differential_report_category_valid' \
    'StatusCategoryMismatch' \
    'ComparisonStatusMismatch' \
    'report.status == DifferentialReportStatus.Passed and report.comparison_kind != DifferentialReportDifferenceKind.Equal' \
    'report.status == DifferentialReportStatus.Failed and (report.comparison_kind == DifferentialReportDifferenceKind.Equal or report.comparison_kind == DifferentialReportDifferenceKind.Unavailable)' \
    'NondeterministicPass' \
    'NondeterministicClaimInvalid' \
    'FlakyEvidenceInvalid' \
    'StabilityEvidenceInvalid' \
    'DetailOmissionInvalid' \
    'report.repeat_count < 2' \
    'validate_differential_stability(report.stability_evidence)' \
    'report.repeat_count != report.stability_evidence.observations.count' \
    'report.stability_evidence.state != DifferentialStabilityState.Planned' \
    'DifferentialStabilityClassification.Nondeterministic' \
    'MessageLimitExceeded' \
    'AggregateTextLimitExceeded' \
    'EmbeddedNul' \
    'InvalidUtf8' \
    'differential_report_text_length_valid' \
    'differential_report_text_total_add_fits' \
    'differential_report_text_utf8_valid' \
    'not differential_report_text_utf8_valid(report.artifact_path)' \
    'not differential_report_text_utf8_valid(report.reference_detail)' \
    'not differential_report_text_utf8_valid(report.candidate_detail)' \
    'RepeatCountInvalid'; do
    rg -Fq "$boundary" "$model"
done
aggregate_preflight_line="$(rg -n -m1 -F 'differential_report_text_total_add_fits(total_text_bytes, message)' "$model" | cut -d: -f1)"
embedded_nul_scan_line="$(rg -n -m1 -F 'EmbeddedNul if sview_contains_byte(message, 0)' "$model" | cut -d: -f1)"
[[ -n "$aggregate_preflight_line" && -n "$embedded_nul_scan_line" ]]
(( aggregate_preflight_line < embedded_nul_scan_line ))

rg -Fq 'include "./report_model.elisa"' "$consumer"
rg -Fq 'include "./report_render_model.elisa"' "$consumer"
rg -Fq 'include "./report_transport_model.elisa"' "$consumer"
rg -Fq 'include "./report_transport_posix.elisa"' "$consumer"
rg -Fq 'include "./report_adapter_model.elisa"' "$consumer"
stability_include_line="$(rg -n -m1 -F 'include "./stability_model.elisa"' "$consumer" | cut -d: -f1)"
report_include_line="$(rg -n -m1 -F 'include "./report_model.elisa"' "$consumer" | cut -d: -f1)"
[[ -n "$stability_include_line" && -n "$report_include_line" ]]
(( stability_include_line < report_include_line ))
if ! rg -Uq '(?m)^@test\r?\ndef differential_report_contract_is_machine_readable_and_fail_closed\(\) -> void:' "$fixture"; then
    printf 'differential report audit: registered report contract test is missing\n' >&2
    exit 1
fi
report_fixture_body="$(awk '
    /^def differential_report_contract_is_machine_readable_and_fail_closed\(\) -> void:$/ { in_fixture = 1; next }
    in_fixture && /^@test$/ { exit }
    in_fixture { print }
' "$fixture")"
rg -Fq 'using EsDifferentialReport' "$fixture"
for fixture_pattern in \
    'DifferentialReportFormat.Json' \
    'DifferentialReportFormat.Junit' \
    'DifferentialReportError.StatusCategoryMismatch' \
    'DifferentialReportError.ComparisonStatusMismatch' \
    'comparison_kind: DifferentialReportDifferenceKind.ExitStatus' \
    'comparison_kind: DifferentialReportDifferenceKind.Equal' \
    'forged_failure_unavailable' \
    'DifferentialReportError.NondeterministicPass' \
    'DifferentialReportError.FlakyEvidenceInvalid' \
    'DifferentialReportError.NondeterministicClaimInvalid' \
    'has_stability_evidence: true' \
    'aggregate_text_messages' \
    'DifferentialReportError.AggregateTextLimitExceeded' \
    'embedded_nul_message' \
    'DifferentialReportError.EmbeddedNul' \
    'invalid_utf8_text' \
    'DifferentialReportError.InvalidUtf8' \
    'invalid_utf8_artifact_path' \
    'invalid_utf8_artifact_path_rejected' \
    'repeated_pass' \
    'mismatched_evidence_count' \
    'flaky_stability' \
    'hidden_stability_evidence' \
    'flaky_without_repeats' \
    'stable_flaky_label' \
    'nondeterministic_failure'; do
    if ! rg -Fq "$fixture_pattern" <<< "$report_fixture_body"; then
        printf 'differential report audit: contract case is absent from its test body: %s\n' "$fixture_pattern" >&2
        exit 1
    fi
done

if ! rg -Uq '(?m)^@test\r?\ndef differential_report_json_renderer_is_deterministic_escaped_and_bounded\(\) -> void:' "$fixture"; then
    printf 'differential report audit: JSON renderer regression is not registered\n' >&2
    exit 1
fi
rg -Fq 'DifferentialReportRenderError.OutputLimitExceeded' "$fixture"
rg -Fq 'sview_eq(rendered, expected)' "$fixture"
rg -Fq '9007199254740993u64' "$fixture"
rg -Fq 'differential_test_sview_contains(evidence_text' "$fixture"
if ! rg -Uq '(?m)^@test\r?\ndef differential_report_human_and_junit_renderers_preserve_outcomes\(\) -> void:' "$fixture"; then
    printf 'differential report audit: Human/JUnit renderer regression is not registered\n' >&2
    exit 1
fi
rg -Fq '<failure type=\"value_mismatch\" message=\"diff &amp; &lt;\"/>' "$fixture"
rg -Fq 'DifferentialReportRenderError.XmlCharacterInvalid' "$fixture"
rg -Fq 'render_differential_report(human_report)' "$fixture"
rg -Fq 'inconclusive_evidence' "$fixture"
if ! rg -Uq '(?m)^@test\r?\ndef differential_report_transport_requires_full_ordered_writes\(\) -> void:' "$fixture"; then
    printf 'differential report audit: transport regression is not registered\n' >&2
    exit 1
fi
rg -Fq 'DifferentialReportTransportError.ShortWrite' "$fixture"
rg -Fq 'peek_differential_report_chunk' "$fixture"
rg -Fq 'transport.offset == transport.bytes.count' "$fixture"
if ! rg -Uq '(?m)^@test\r?\ndef differential_report_posix_transport_rejects_invalid_descriptor_before_write\(\) -> void:' "$fixture"; then
    printf 'differential report audit: POSIX transport regression is not registered\n' >&2
    exit 1
fi
rg -Fq 'DifferentialReportTransportPosixError.InvalidDescriptor' "$fixture"
if ! rg -Uq '(?m)^@test\r?\ndef differential_report_adapter_preserves_comparison_identity_and_category\(\) -> void:' "$fixture"; then
    printf 'differential report audit: comparison adapter regression is not registered\n' >&2
    exit 1
fi
rg -Fq 'make_differential_report(case, reference_run, candidate_run' "$fixture"
rg -Fq 'make_differential_case_replay_report(case, session' "$fixture"
rg -Fq 'record_differential_case_replay_stability_observation(stable_repeats, case, session)' "$fixture"
rg -Fq 'make_differential_case_stability_report(case, varying_repeats, session' "$fixture"
rg -Fq 'DifferentialReportCategory.Flaky' "$fixture"
rg -Fq 'DifferentialReportStatus.Inconclusive' "$fixture"
rg -Fq 'reference_detail: comparison.reference_text' "$adapter"
rg -Fq 'candidate_detail: comparison.candidate_text' "$adapter"
rg -Fq '"reference_detail"' "$renderer"
rg -Fq '"candidate_detail"' "$renderer"
rg -Fq 'report.comparison_kind' "$renderer"
rg -Fq 'report.comparison_index' "$renderer"
rg -Fq 'reference_detail_omitted' "$model"
rg -Fq 'candidate_detail_omitted' "$model"
rg -Fq 'sview_len(projected_comparison.reference_text) >= EsDifferentialReport::Limits::TEXT_BYTES' "$adapter"
rg -Fq 'sview_len(projected_comparison.candidate_text) >= EsDifferentialReport::Limits::TEXT_BYTES' "$adapter"
rg -Fq 'DifferentialReportStatus.Inconclusive' "$fixture"
rg -Fq 'DifferentialReportCategory.ValueMismatch' "$fixture"
rg -Fq 'both_timed_out.status == DifferentialReportStatus.Inconclusive' "$fixture"
rg -Fq 'one_sided_timeout.status == DifferentialReportStatus.Failed' "$fixture"
rg -Fq 'both_compile_failed.status == DifferentialReportStatus.Inconclusive' "$fixture"

rg -Fq 'EsDifferentialReport::DifferentialReport' "$docs"
rg -Fq 'merely setting a repeat count is insufficient' "$docs"
rg -Fq 'render_differential_report' "$docs"
rg -Fq 'Human, JSON, or JUnit' "$docs"

printf 'differential report audit: typed reports bind repeat claims and render bounded Human/JSON/JUnit output\n'
