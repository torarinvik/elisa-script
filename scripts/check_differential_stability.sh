#!/usr/bin/env bash

# Compiler-free audit for bounded differential repeat and nondeterminism policy.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/stability_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$consumer" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'differential stability audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialStability:' \
    'Limits::REPEATS' \
    'const enum DifferentialStabilityState of u8:' \
    'const enum DifferentialStabilityEvent of u8:' \
    'const enum DifferentialStabilityClassification of u8:' \
    'const enum DifferentialNondeterminismPolicy of u8:' \
    'struct DifferentialStabilityPolicy:' \
    'struct DifferentialStabilityObservation:' \
    'struct DifferentialStabilitySession:' \
    'error DifferentialStabilityError:' \
    'def validate_differential_stability(' \
    'def advance_differential_stability('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'minimum_repeats' \
    'maximum_repeats' \
    'NondeterministicRejected' \
    'DifferentialNondeterminismPolicy.Reject' \
    'DifferentialNondeterminismPolicy.Report' \
    'has_nondeterminism' \
    'expected_stable_repeats' \
    'expected_nondeterminism' \
    'session.stable_repeats != expected_stable_repeats' \
    'session.has_nondeterminism != expected_nondeterminism' \
    'StableEqual' \
    'StableMismatch' \
    'CompleteNotReady' \
    'RepeatOrderInvalid'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./stability_model.elisa"' "$consumer"
rg -Fq 'using EsDifferentialStability' "$fixture"
for fixture_pattern in \
    'differential_stability_contract_classifies_stable_and_nondeterministic_repeats' \
    'DifferentialStabilityEvent.Observation' \
    'DifferentialStabilityClassification.StableEqual' \
    'DifferentialStabilityClassification.Nondeterministic' \
    'DifferentialStabilityError.NondeterministicRejected'; do
    rg -Fq "$fixture_pattern" "$fixture"
done
rg -Fq 'forged_stability_accounting' "$fixture"

rg -Fq 'EsDifferentialStability::DifferentialStabilitySession' "$docs"
rg -Fq 'P13 repeat-stability follow-up' "$plan"

printf 'differential stability audit: bounded repeats, explicit stable classifications, and fail-closed nondeterminism policy are present\n'
