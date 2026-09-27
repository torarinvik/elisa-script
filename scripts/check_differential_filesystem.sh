#!/usr/bin/env bash

# Compiler-free audit for bounded differential filesystem snapshots.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/filesystem_snapshot_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"
max_source_bytes=16777216
max_total_source_bytes=33554432

rg_bounded() {
    command rg --max-filesize "$max_source_bytes" "$@"
}

for required_file in "$model" "$consumer" "$ir" "$fixture" "$docs"; do
    [[ -f "$required_file" && -r "$required_file" ]] || { printf 'differential filesystem audit: missing %s\n' "$required_file" >&2; exit 1; }
done

total_source_bytes=0
for required_file in "$model" "$consumer" "$ir" "$fixture" "$docs"; do
    if ! source_size_text="$(wc -c < "$required_file" | tr -d '[:space:]')"; then
        printf 'differential filesystem audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
    case "$source_size_text" in
        ''|*[!0-9]*)
            printf 'differential filesystem audit: missing %s\n' "$required_file" >&2
            exit 1
            ;;
    esac
    if (( ${#source_size_text} > 8 )); then
        source_size=$((max_source_bytes + 1))
    else
        source_size=$((10#$source_size_text))
    fi
    if (( source_size > max_source_bytes || source_size > max_total_source_bytes - total_source_bytes )); then
        printf 'differential filesystem audit: source exceeds audit limit: %s\n' "$required_file" >&2
        exit 2
    fi
    total_source_bytes=$((total_source_bytes + source_size))
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
    'def differential_filesystem_hash_mix(' \
    'def differential_filesystem_entry_mode_valid(' \
    'def compare_differential_filesystem_snapshots(' \
    'def copy_differential_filesystem_entry_path(' \
    'def copy_differential_filesystem_entry_content('; do
    rg_bounded -Fq "$declaration" "$model"
done

for boundary in \
    'differential_filesystem_path_safe' \
    'differential_filesystem_path_span_safe' \
    'differential_filesystem_entries_path_data_contiguous' \
    'differential_filesystem_entries_content_data_contiguous' \
    'differential_filesystem_entries_ancestors_valid' \
    'differential_filesystem_compact_sorted_data' \
    'differential_filesystem_sort_entries' \
    'PathStorageLimitExceeded' \
    'SnapshotAccountingInvalid' \
    'AncestorNotDirectory' \
    'InvalidMode' \
    'mode > 511u32' \
    'mode & 73u32' \
    'differential_filesystem_entry_mode_valid(entry.kind, entry.mode, entry.executable)' \
    'InvalidMode if not differential_filesystem_entry_mode_valid(entry.kind, entry.mode, entry.executable)' \
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
    rg_bounded -Fq "$boundary" "$model"
done

rg_bounded -Fq 'EsHash::hash_wrapping_add_u64(EsHash::hash_wrapping_multiply_u64(hash, DIFFERENTIAL_FILESYSTEM_HASH_PRIME), value)' "$model"
rg_bounded -Fq 'differential_filesystem_hash_mix(result, snapshot.total_bytes.u64())' "$model"
if rg_bounded -Fq 'result <- result * DIFFERENTIAL_FILESYSTEM_HASH_PRIME' "$model"; then
    printf 'differential filesystem audit: fingerprint regressed to checked-overflow arithmetic\n' >&2
    exit 1
fi
rg_bounded -Fq 'include "../runtime/hash_model.elisa"' "$ir"
rg_bounded -Fq 'include "./filesystem_snapshot_model.elisa"' "$consumer"
rg_bounded -Fq 'using EsDifferentialFilesystem' "$fixture"
for fixture_pattern in \
    'differential_filesystem_snapshot_contract_orders_entries_and_reports_first_difference' \
    'DifferentialFilesystemEntryKind.Directory' \
    'DifferentialFilesystemError.EntryOrderInvalid' \
    'DifferentialFilesystemDifferenceKind.Equal' \
    'DifferentialFilesystemDifferenceKind.Content' \
    'assert differential_filesystem_snapshot_fingerprint(reference) == differential_filesystem_snapshot_fingerprint(candidate)' \
    'copy_differential_filesystem_entry_path' \
    'copy_differential_filesystem_entry_content' \
    'differential_filesystem_compares_binary_files_and_raw_symlink_targets' \
    'posix_backslash_path' \
    'path_data.count' \
    'content_data.count' \
    'differential_filesystem_unordered_batch_is_bounded_sorted_and_sealed' \
    'differential_filesystem_rejects_non_directory_ancestors' \
    'differential_filesystem_requires_canonical_permission_metadata' \
    'forged_path_copy_rejected' \
    'forged_content_copy_rejected' \
    'DifferentialFilesystemError.InvalidMode' \
    'DifferentialFilesystemError.AncestorNotDirectory' \
    'DifferentialFilesystemError.PathStorageLimitExceeded' \
    'DifferentialFilesystemState.Cancelled'; do
    rg_bounded -Fq "$fixture_pattern" "$fixture"
done

rg_bounded -Fq 'EsDifferentialFilesystem::DifferentialFilesystemSnapshot' "$docs"
rg_bounded -Fq 'Exact-payload snapshot contract' "$docs"
rg_bounded -Fq 'ordinary permission bits (`0000` through `0777`)' "$docs"
rg_bounded -Fq 'executable marker must match those bits' "$docs"
rg_bounded -Fq 'backslash is an' "$docs"

printf 'differential filesystem audit: bounded exact payload snapshots, valid tree ancestors, fingerprints, and first-difference comparison are present\n'
