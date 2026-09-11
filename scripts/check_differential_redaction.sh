#!/usr/bin/env bash

# Compiler-free audit for explicit differential artifact redaction.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/redaction_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$consumer" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'differential redaction audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q 'available < 2' "$model"
rg -q 'value_length > available - 2' "$model"

for declaration in \
    'module EsDifferentialRedaction:' \
    'DIFFERENTIAL_REDACTION_MAX_RULES' \
    'DIFFERENTIAL_REDACTION_MAX_ENTRIES' \
    'const enum DifferentialRedactionState of u8:' \
    'const enum DifferentialRedactionEvent of u8:' \
    'struct DifferentialRedactionPolicy:' \
    'struct DifferentialRedactionSourceEntry:' \
    'struct DifferentialRedactionEntry:' \
    'struct DifferentialRedactionSession:' \
    'error DifferentialRedactionError:' \
    'def validate_differential_redaction_session(' \
    'def advance_differential_redaction('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'redact_all' \
    'value_fingerprint' \
    'redacted' \
    'DuplicateName' \
    'TextLimitExceeded' \
    'expected_text_bytes' \
    'session.text_bytes != expected_text_bytes' \
    'differential_redaction_name_selected' \
    'differential_redaction_value_fingerprint'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./redaction_model.elisa"' "$consumer"
rg -Fq 'using EsDifferentialRedaction' "$fixture"
for fixture_pattern in \
    'differential_redaction_contract_preserves_fingerprints_without_secret_values' \
    'DifferentialRedactionEvent.Capture' \
    'assert session.entries[1].value == ""' \
    'DifferentialRedactionError.DuplicateName' \
    'forged_redaction_duplicate'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsDifferentialRedaction::DifferentialRedactionPolicy' "$docs"
rg -Fq 'P13 redaction follow-up' "$plan"

printf 'differential redaction audit: bounded explicit secret selection, value fingerprints, and omission are present\n'
