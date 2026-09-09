#!/usr/bin/env bash

# Compiler-free audit for bounded differential lockstep sequences.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/sequence_model.elisa"
differential="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$differential" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'differential sequence audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialSequence:' \
    'DIFFERENTIAL_SEQUENCE_MAX_STEPS' \
    'const enum DifferentialSequenceState of u8:' \
    'const enum DifferentialSequenceEvent of u8:' \
    'struct DifferentialSequenceStep:' \
    'struct DifferentialSequenceCheckpoint:' \
    'struct DifferentialSequence:' \
    'error DifferentialSequenceError:' \
    'def validate_differential_sequence(' \
    'def advance_differential_sequence('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'first_divergence' \
    'CheckpointOrderInvalid' \
    'StepOrderInvalid' \
    'ObservationLimitExceeded' \
    'ObservationAccountingInvalid' \
    'CompletionNotReady' \
    'DivergenceStateInvalid'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./sequence_model.elisa"' "$differential"
for fixture_pattern in \
    'differential_sequence_contract_localizes_first_divergence_and_checkpoints' \
    'DifferentialSequenceEvent.Checkpoint' \
    'DifferentialSequenceState.Diverged' \
    'DifferentialSequenceError.StepOrderInvalid' \
    'forged_observation_accounting'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsDifferentialSequence::DifferentialSequence`' "$docs"
rg -Fq 'P13 lockstep-sequence follow-up' "$plan"

printf 'differential sequence audit: bounded lockstep steps, checkpoints, and first-divergence localization are present\n'
