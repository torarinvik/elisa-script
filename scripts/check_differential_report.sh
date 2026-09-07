#!/usr/bin/env bash

# Compiler-free audit for typed differential report output.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/report_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$consumer" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'differential report audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialReport:' \
    'DIFFERENTIAL_REPORT_MAX_TEXT_BYTES' \
    'DIFFERENTIAL_REPORT_MAX_MESSAGES' \
    'DIFFERENTIAL_REPORT_MAX_REPEATS' \
    'const enum DifferentialReportFormat of u8:' \
    'const enum DifferentialReportStatus of u8:' \
    'const enum DifferentialReportCategory of u8:' \
    'struct DifferentialReport:' \
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
    'MessageLimitExceeded' \
    'RepeatCountInvalid'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./report_model.elisa"' "$consumer"
rg -Fq 'using EsDifferentialReport' "$fixture"
for fixture_pattern in \
    'differential_report_contract_is_machine_readable_and_fail_closed' \
    'DifferentialReportFormat.Json' \
    'DifferentialReportFormat.Junit' \
    'DifferentialReportError.StatusCategoryMismatch' \
    'DifferentialReportError.NondeterministicPass'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsDifferentialReport::DifferentialReport' "$docs"
rg -Fq 'P13 report follow-up' "$plan"

printf 'differential report audit: typed formats, statuses, failure categories, identities, and bounded messages are present\n'
