#!/usr/bin/env bash

# Compiler-free audit for the typed differential replay lifecycle.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/replay_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$consumer" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'differential replay audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialReplay:' \
    'DIFFERENTIAL_REPLAY_MAX_RUNS' \
    'const enum DifferentialReplayOrder of u8:' \
    'const enum DifferentialReplayState of u8:' \
    'const enum DifferentialReplayEvent of u8:' \
    'const enum DifferentialReplaySide of u8:' \
    'struct DifferentialReplaySession:' \
    'error DifferentialReplayError:' \
    'def validate_differential_replay_session(' \
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
    'DifferentialReplayState.Comparing' \
    'DifferentialReplayState.Restoring'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./replay_model.elisa"' "$consumer"
rg -Fq 'using EsDifferentialReplay' "$fixture"
for fixture_pattern in \
    'differential_replay_contract_requires_admission_ordered_runs_and_restoration' \
    'DifferentialReplayEvent.Admit' \
    'DifferentialReplayEvent.CompareComplete' \
    'DifferentialReplayEvent.RestoreComplete' \
    'DifferentialReplayError.RunOrderInvalid' \
    'forged_completed_replay'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsDifferentialReplay::DifferentialReplaySession' "$docs"
rg -Fq 'P13 replay-lifecycle follow-up' "$plan"

printf 'differential replay audit: bounded admission, ordered side execution, comparison, and world restoration are present\n'
