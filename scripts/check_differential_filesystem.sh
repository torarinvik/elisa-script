#!/usr/bin/env bash

# Compiler-free audit for bounded differential filesystem snapshots.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/filesystem_snapshot_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"

for required_file in "$model" "$consumer" "$fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'differential filesystem audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialFilesystem:' \
    'Limits::ENTRIES' \
    'Limits::PATH_STORAGE_BYTES' \
    'Limits::TOTAL_BYTES' \
    'const enum DifferentialFilesystemEntryKind of u8:' \
    'const enum DifferentialFilesystemState of u8:' \
    'const enum DifferentialFilesystemEvent of u8:' \
    'struct DifferentialFilesystemEntry:' \
    'struct DifferentialFilesystemEntryRecord:' \
    'struct DifferentialFilesystemSnapshot:' \
    'const enum DifferentialFilesystemDifferenceKind of u8:' \
    'struct DifferentialFilesystemDifference:' \
    'error DifferentialFilesystemError:' \
    'def validate_differential_filesystem_snapshot(' \
    'def collect_unordered_differential_filesystem_entry(' \
    'def seal_unordered_differential_filesystem_snapshot(' \
    'def advance_differential_filesystem_snapshot(' \
    'def differential_filesystem_snapshot_fingerprint(' \
    'def compare_differential_filesystem_snapshots(' \
    'def copy_differential_filesystem_entry_path(' \
    'def copy_differential_filesystem_entry_content('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'differential_filesystem_path_safe' \
    'differential_filesystem_path_span_safe' \
    'differential_filesystem_entries_path_data_contiguous' \
    'differential_filesystem_entries_content_data_contiguous' \
    'differential_filesystem_compact_sorted_data' \
    'differential_filesystem_sort_entries' \
    'PathStorageLimitExceeded' \
    'SnapshotAccountingInvalid' \
    'EntryOrderInvalid' \
    'ByteLimitExceeded' \
    'SnapshotNotSealed' \
    'MissingReference' \
    'MissingCandidate' \
    'DifferentialFilesystemDifferenceKind.Content' \
    'DifferentialFilesystemDifferenceKind.Executable' \
    'has_reference_entry' \
    'has_candidate_entry' \
    'path_data: darray[u8]' \
    'content_data: darray[u8]' \
    'content_start: usize' \
    'content_bytes: usize' \
    'filesystem entry bytes differ'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./filesystem_snapshot_model.elisa"' "$consumer"
rg -Fq 'using EsDifferentialFilesystem' "$fixture"
for fixture_pattern in \
    'differential_filesystem_snapshot_contract_orders_entries_and_reports_first_difference' \
    'DifferentialFilesystemEntryKind.Directory' \
    'DifferentialFilesystemError.EntryOrderInvalid' \
    'DifferentialFilesystemDifferenceKind.Equal' \
    'DifferentialFilesystemDifferenceKind.Content' \
    'copy_differential_filesystem_entry_path' \
    'copy_differential_filesystem_entry_content' \
    'differential_filesystem_compares_binary_files_and_raw_symlink_targets' \
    'posix_backslash_path' \
    'path_data.count' \
    'content_data.count' \
    'differential_filesystem_unordered_batch_is_bounded_sorted_and_sealed' \
    'DifferentialFilesystemError.PathStorageLimitExceeded' \
    'DifferentialFilesystemState.Cancelled'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsDifferentialFilesystem::DifferentialFilesystemSnapshot' "$docs"
rg -Fq 'Exact-payload snapshot contract' "$docs"
rg -Fq 'backslash is an' "$docs"

printf 'differential filesystem audit: exact bounded payload snapshots, fingerprints, and first-difference comparison are present\n'
