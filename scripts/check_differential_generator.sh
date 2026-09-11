#!/usr/bin/env bash

# Compiler-free audit for bounded deterministic differential generators.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/generator_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$consumer" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'differential generator audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialGenerator:' \
    'DIFFERENTIAL_GENERATOR_MAX_CASES' \
    'DIFFERENTIAL_GENERATOR_MAX_BYTES' \
    'const enum DifferentialGeneratorState of u8:' \
    'const enum DifferentialGeneratorEvent of u8:' \
    'struct DifferentialGeneratorPolicy:' \
    'struct DifferentialGeneratedInput:' \
    'struct DifferentialGeneratorSession:' \
    'error DifferentialGeneratorError:' \
    'def validate_differential_generator_session(' \
    'def advance_differential_generator('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'base_seed' \
    'differential_generator_case_seed' \
    'SeedMismatch' \
    'CaseOrderInvalid' \
    'ByteLimitExceeded' \
    'expected_bytes' \
    'session.generated_bytes != expected_bytes' \
    'CompleteNotReady'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./generator_model.elisa"' "$consumer"
rg -Fq 'using EsDifferentialGenerator' "$fixture"
for fixture_pattern in \
    'differential_generator_contract_derives_case_seeds_and_bounds_payloads' \
    'DifferentialGeneratorEvent.Generate' \
    'DifferentialGeneratorError.SeedMismatch' \
    'DifferentialGeneratorState.Completed' \
    'forged_generator_bytes'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsDifferentialGenerator::DifferentialGeneratorSession' "$docs"
rg -Fq 'P13 generator follow-up' "$plan"

printf 'differential generator audit: bounded reproducible case seeds, ordering, and aggregate payload limits are present\n'
