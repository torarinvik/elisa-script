#!/usr/bin/env bash

# Compiler-free audit for bounded filesystem metadata snapshots.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/file_metadata_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'file metadata audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsFileMetadata:' "$model"
rg -q 'include "\.\./runtime/file_metadata_model\.elisa"' "$ir"
for declaration in \
    'const module Limits:' \
    'const enum FileMetadataKind of u8' \
    'const enum FileMetadataState of u8' \
    'const enum FileMetadataEvent of u8' \
    'struct FileMetadataPolicy:' \
    'struct FileMetadataEntry:' \
    'struct FileMetadataSnapshot:' \
    'error FileMetadataError:' \
    'def validate_file_metadata_snapshot\(' \
    'def file_metadata_lookup\(' \
    'def advance_file_metadata\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'Limits::ENTRIES' \
    'Limits::PATH_BYTES' \
    'Limits::TARGET_BYTES' \
    'Limits::TOTAL_BYTES' \
    'file_metadata_index' \
    'allow_missing' \
    'preserve_symlink' \
    'raise FileMetadataError.EmbeddedNul if sview_contains_byte(entry.path, 0) or sview_contains_byte(entry.target, 0)' \
    'raise FileMetadataError.EmbeddedNul if sview_contains_byte(path, 0)' \
    'FileMetadataKind.Symlink' \
    'FileMetadataKind.Missing' \
    'raise FileMetadataError.InvalidIdentity if entry.kind == FileMetadataKind.Missing and (entry.inode != 0 or entry.device != 0 or entry.link_count != 0)' \
    'raise FileMetadataError.InvalidSize if entry.kind == FileMetadataKind.Missing and entry.size != 0' \
    'entry.kind == FileMetadataKind.Missing and (entry.mode != 0' \
    'FileMetadataError.DuplicatePath' \
    'FileMetadataError.InvalidIdentity' \
    'FileMetadataError.SymlinkTargetInvalid' \
    'FileMetadataError.AccountingInvalid' \
    'FileMetadataState.Planned and' \
    'FileMetadataEvent.Entry' \
    'FileMetadataState.Sealed'; do
    rg -Fq "$boundary" "$model"
done

for fixture_pattern in \
    'using EsFileMetadata' \
    'typed_file_metadata_contract_is_bounded_and_symlink_explicit' \
    'FileMetadataKind.Symlink' \
    'FileMetadataKind.Missing' \
    'file_metadata_lookup' \
    'FileMetadataError.DuplicatePath' \
    'FileMetadataError.SymlinkTargetInvalid' \
    'FileMetadataError.EmbeddedNul' \
    'FileMetadataError.AccountingInvalid' \
    'forged_missing_metadata'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsFileMetadata::FileMetadataSnapshot' "$docs"
rg -q 'ES-FS-002' "$ledger"

printf 'file metadata audit: bounded stat/lstat shape, symlink policy, and lookup are present\n'
