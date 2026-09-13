#!/usr/bin/env bash

# Compiler-free audit for bounded differential filesystem snapshots.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/filesystem_snapshot_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$consumer" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'differential filesystem audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialFilesystem:' \
    'Limits::ENTRIES' \
    'Limits::TOTAL_BYTES' \
    'const enum DifferentialFilesystemEntryKind of u8:' \
    'const enum DifferentialFilesystemState of u8:' \
    'const enum DifferentialFilesystemEvent of u8:' \
    'struct DifferentialFilesystemEntry:' \
    'struct DifferentialFilesystemSnapshot:' \
    'const enum DifferentialFilesystemDifferenceKind of u8:' \
    'struct DifferentialFilesystemDifference:' \
    'error DifferentialFilesystemError:' \
    'def validate_differential_filesystem_snapshot(' \
    'def advance_differential_filesystem_snapshot(' \
    'def differential_filesystem_snapshot_fingerprint(' \
    'def compare_differential_filesystem_snapshots('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'differential_filesystem_path_safe' \
    'differential_filesystem_text_less' \
    'EntryOrderInvalid' \
    'ByteLimitExceeded' \
    'SnapshotNotSealed' \
    'MissingReference' \
    'MissingCandidate' \
    'DifferentialFilesystemDifferenceKind.Content' \
    'DifferentialFilesystemDifferenceKind.Executable'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./filesystem_snapshot_model.elisa"' "$consumer"
rg -Fq 'using EsDifferentialFilesystem' "$fixture"
for fixture_pattern in \
    'differential_filesystem_snapshot_contract_orders_entries_and_reports_first_difference' \
    'DifferentialFilesystemEntryKind.Directory' \
    'DifferentialFilesystemError.EntryOrderInvalid' \
    'DifferentialFilesystemDifferenceKind.Equal' \
    'DifferentialFilesystemDifferenceKind.Content'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsDifferentialFilesystem::DifferentialFilesystemSnapshot' "$docs"
rg -Fq 'P13 filesystem-snapshot follow-up' "$plan"

printf 'differential filesystem audit: bounded ordered snapshots, fingerprints, and first-difference comparison are present\n'
