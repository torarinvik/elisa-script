#!/usr/bin/env bash

# Compiler-free audit for bounded algebraic-effect differential traces.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/effect_trace_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$consumer" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'differential effect-trace audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialEffectTrace:' \
    'DIFFERENTIAL_EFFECT_TRACE_MAX_EVENTS' \
    'DIFFERENTIAL_EFFECT_TRACE_MAX_RESUMPTIONS' \
    'const enum DifferentialEffectTraceState of u8:' \
    'const enum DifferentialEffectTraceEvent of u8:' \
    'struct DifferentialEffectEvent:' \
    'struct DifferentialEffectTrace:' \
    'const enum DifferentialEffectDifferenceKind of u8:' \
    'struct DifferentialEffectDifference:' \
    'error DifferentialEffectTraceError:' \
    'def validate_differential_effect_trace(' \
    'def advance_differential_effect_trace(' \
    'def differential_effect_trace_fingerprint(' \
    'def compare_differential_effect_traces('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'payload_fingerprint' \
    'result_fingerprint' \
    'resumption_count' \
    'MultishotInvalid' \
    'DifferentialEffectDifferenceKind.Family' \
    'DifferentialEffectDifferenceKind.Operation' \
    'DifferentialEffectDifferenceKind.Payload' \
    'DifferentialEffectDifferenceKind.Resumption' \
    'DifferentialEffectDifferenceKind.Invalid' \
    'sequence_index != index'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./effect_trace_model.elisa"' "$consumer"
rg -Fq 'using EsDifferentialEffectTrace' "$fixture"
for fixture_pattern in \
    'differential_effect_trace_contract_preserves_operation_and_resumption_differences' \
    'DifferentialEffectTraceEvent.Record' \
    'DifferentialEffectDifferenceKind.Equal' \
    'DifferentialEffectDifferenceKind.Operation' \
    'DifferentialEffectDifferenceKind.Invalid' \
    'malformed_sequence'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsDifferentialEffectTrace::DifferentialEffectTrace' "$docs"
rg -Fq 'P13 effect-trace follow-up' "$plan"

printf 'differential effect-trace audit: bounded operation identities, resumption counts, fingerprints, and first differences are present\n'
