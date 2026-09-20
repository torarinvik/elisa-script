#!/usr/bin/env bash

# Compiler-free audit for typed differential report output.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/report_model.elisa"
renderer="$repo_root/src/testing/report_render_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"

for required_file in "$model" "$renderer" "$consumer" "$fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'differential report audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for renderer_boundary in \
    'module EsDifferentialReportRender:' \
    'const module Limits:' \
    'MAX_BYTES: usize = 33554432' \
    'def render_differential_report_json(' \
    'validate_differential_report(report)' \
    'report.format != DifferentialReportFormat.Json' \
    'OutputLimitExceeded' \
    'report_render_append_json_string' \
    'report_render_append_stability' \
    'baseline_reference_fingerprint' \
    'comparison_fingerprint' \
    'report.messages.count'; do
    rg -Fq "$renderer_boundary" "$renderer"
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
    'NondeterministicPass' \
    'NondeterministicClaimInvalid' \
    'FlakyEvidenceInvalid' \
    'StabilityEvidenceInvalid' \
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
    'RepeatCountInvalid'; do
    rg -Fq "$boundary" "$model"
done
aggregate_preflight_line="$(rg -n -m1 -F 'differential_report_text_total_add_fits(total_text_bytes, message)' "$model" | cut -d: -f1)"
embedded_nul_scan_line="$(rg -n -m1 -F 'EmbeddedNul if sview_contains_byte(message, 0)' "$model" | cut -d: -f1)"
[[ -n "$aggregate_preflight_line" && -n "$embedded_nul_scan_line" ]]
(( aggregate_preflight_line < embedded_nul_scan_line ))

rg -Fq 'include "./report_model.elisa"' "$consumer"
rg -Fq 'include "./report_render_model.elisa"' "$consumer"
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

rg -Fq 'EsDifferentialReport::DifferentialReport' "$docs"
rg -Fq 'merely setting a repeat count is insufficient' "$docs"
rg -Fq 'render_differential_report_json' "$docs"

printf 'differential report audit: typed reports bind repeat claims and render bounded JSON evidence\n'
