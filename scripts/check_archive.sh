#!/usr/bin/env bash

# Compiler-free audit for bounded archive extraction admission.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/archive_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
runtime_fixture="$repo_root/test/runtime/archive_model_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture_file" "$runtime_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'archive audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q 'id_index_slots: darray\[usize\]' "$model"
rg -q 'path_index_slots: darray\[usize\]' "$model"
rg -q 'def archive_entry_id_index\(' "$model"
rg -q 'def archive_path_index\(' "$model"
rg -q 'def archive_ensure_index_capacity\(' "$model"
rg -q 'def validate_archive_header\(' "$model"
rg -q 'try validate_archive_header\(session\)' "$model"
rg -q 'INDEX_SLOTS: usize = 2097152' "$model"
rg -q 'if entry.state == ArchiveEntryState.Accepted and session.policy.overwrite == ArchiveOverwritePolicy.Fail' "$model"
rg -q 'archive_path_index\(session.entries, session.path_index_slots, entry.path\)' "$model"
rg -q 'for stored in session.id_index_slots' "$model"
rg -q 'for stored in session.path_index_slots' "$model"
! rg -Fq 'for earlier in 0..<index' "$model"
rg -q 'skipped_archive_paths_do_not_conflict_with_accepted_entries' "$runtime_fixture"
rg -q 'archive_entry_indexes_preserve_order_across_collisions_and_growth' "$runtime_fixture"
rg -q 'session.id_index_slots.count == 16 and session.path_index_slots.count == 16' "$runtime_fixture"
rg -q 'ArchiveError.DuplicatePath' "$runtime_fixture"
rg -q 'ArchiveError.DuplicateEntryId' "$runtime_fixture"
rg -q 'ArchiveEntryState.Skipped' "$runtime_fixture"
rg -q 'first_accepted.total_bytes == 3 and first_accepted.skipped_entries == 1' "$runtime_fixture"
rg -q 'first_skipped.total_bytes == 3 and first_skipped.skipped_entries == 1' "$runtime_fixture"

rg -q '^module EsArchive:' "$model"
rg -q 'include "\.\./runtime/archive_model\.elisa"' "$ir"
for declaration in \
    'const enum ArchiveKind of u8' \
    'const enum ArchiveLinkPolicy of u8' \
    'const enum ArchiveSessionState of u8' \
    'const enum ArchiveEntryKind of u8' \
    'struct ArchivePolicy:' \
    'struct ArchiveEntry:' \
    'struct ArchiveSession:' \
    'error ArchiveError:' \
    'def validate_archive_session\(' \
    'def archive_admit_entry\(' \
    'def advance_archive\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'Limits::ENTRIES' \
    'Limits::PATH_BYTES' \
    'Limits::ENTRY_BYTES' \
    'Limits::TOTAL_BYTES' \
    'ArchiveError.AbsolutePath' \
    'ArchiveError.TraversalPath' \
    'ArchiveError.LinkRejected' \
    'entry.kind != ArchiveEntryKind.Symlink' \
    'ArchiveError.TotalLimitBytesExceeded' \
    'accounted > session.policy.max_total_bytes' \
    'entry.size > session.policy.max_total_bytes - accounted' \
    'archive_trim_trailing_separators' \
    'while finish > 1 and sview_at(path, finish - 1) == 47' \
    'archive_paths_equivalent' \
    'ArchiveError.AccountingInvalid' \
    'ArchiveSessionState.Planned and' \
    'event == ArchiveEvent.Fail' \
    'ArchiveError.InvalidTransition'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsArchive' \
    'typed_archive_contract_rejects_traversal_and_links_before_commit' \
    'ArchiveError.TraversalPath' \
    'ArchiveError.LinkRejected' \
    'ArchiveSessionState.Committed' \
    'directory_separator' \
    'duplicate_trailing_path' \
    'ArchiveError.AccountingInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsArchive::ArchiveSession' "$docs"
rg -q 'ES-SCRIPT-050' "$ledger"

printf 'archive audit: bounded path, byte, link-policy, indexed duplicate admission, and commit validation are present\n'
