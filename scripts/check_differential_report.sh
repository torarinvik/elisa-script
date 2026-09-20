#!/usr/bin/env bash

# Compiler-free audit for typed differential report output.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/report_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"

for required_file in "$model" "$consumer" "$fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'differential report audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialReport:' \
    'using EsDifferentialStability' \
    'Limits::TEXT_BYTES' \
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
    'RepeatCountInvalid'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./report_model.elisa"' "$consumer"
stability_include_line="$(rg -n -m1 -F 'include "./stability_model.elisa"' "$consumer" | cut -d: -f1)"
report_include_line="$(rg -n -m1 -F 'include "./report_model.elisa"' "$consumer" | cut -d: -f1)"
[[ -n "$stability_include_line" && -n "$report_include_line" ]]
(( stability_include_line < report_include_line ))
rg -Fq 'using EsDifferentialReport' "$fixture"
for fixture_pattern in \
    'differential_report_contract_is_machine_readable_and_fail_closed' \
    'DifferentialReportFormat.Json' \
    'DifferentialReportFormat.Junit' \
    'DifferentialReportError.StatusCategoryMismatch' \
    'DifferentialReportError.NondeterministicPass' \
    'DifferentialReportError.FlakyEvidenceInvalid' \
    'DifferentialReportError.NondeterministicClaimInvalid' \
    'has_stability_evidence: true' \
    'repeated_pass' \
    'mismatched_evidence_count' \
    'flaky_stability' \
    'hidden_stability_evidence' \
    'flaky_without_repeats' \
    'stable_flaky_label' \
    'nondeterministic_failure'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsDifferentialReport::DifferentialReport' "$docs"
rg -Fq 'merely setting a repeat count is insufficient' "$docs"

printf 'differential report audit: typed reports bind repeat claims to validated stability evidence\n'
