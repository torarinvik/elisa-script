#!/usr/bin/env bash

# Compiler-free audit for bounded archive extraction admission.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/archive_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'archive audit: missing %s\n' "$required_file" >&2; exit 1; }
done

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
    'ARCHIVE_MAX_ENTRIES' \
    'ARCHIVE_MAX_PATH_BYTES' \
    'ARCHIVE_MAX_ENTRY_BYTES' \
    'ARCHIVE_MAX_TOTAL_BYTES' \
    'ArchiveError.AbsolutePath' \
    'ArchiveError.TraversalPath' \
    'ArchiveError.LinkRejected' \
    'ArchiveError.TotalLimitBytesExceeded' \
    'ArchiveError.InvalidTransition'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsArchive' \
    'typed_archive_contract_rejects_traversal_and_links_before_commit' \
    'ArchiveError.TraversalPath' \
    'ArchiveError.LinkRejected' \
    'ArchiveSessionState.Committed'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsArchive::ArchiveSession' "$docs"
rg -q 'ES-SCRIPT-050' "$ledger"
rg -q 'P8 archive follow-up' "$plan"

printf 'archive audit: bounded path, byte, link-policy, and commit admission are present\n'
