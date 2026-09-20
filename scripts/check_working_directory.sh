#!/usr/bin/env bash

# Compiler-free audit for serialized per-invocation cwd ownership.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/working_directory_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'working directory audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsWorkingDirectory:' "$model"
rg -q 'include "\.\./runtime/working_directory_model\.elisa"' "$ir"
for declaration in \
    'const enum WorkingDirectoryLeaseState of u8' \
    'const enum WorkingDirectoryState of u8' \
    'const enum WorkingDirectoryEvent of u8' \
    'struct WorkingDirectoryPolicy:' \
    'struct WorkingDirectoryTable:' \
    'struct WorkingDirectorySession:' \
    'error WorkingDirectoryError:' \
    'def validate_working_directory_table\(' \
    'def validate_working_directory_session\(' \
    'def advance_working_directory\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'WORKING_DIRECTORY_MAX_CONTEXTS' \
    'WORKING_DIRECTORY_MAX_PATH_BYTES' \
    'WORKING_DIRECTORY_MAX_CHANGES' \
    'working_directory_active' \
    'WorkingDirectoryEvent.ChangeAck' \
    'WorkingDirectoryEvent.RestoreAck' \
    'WorkingDirectoryError.ConcurrentOwner' \
    'table.next_lease_id <= lease.lease_id' \
    'table.next_lease_id == 18446744073709551615u64' \
    'WorkingDirectoryError.CancelNotReady' \
    'WorkingDirectoryLeaseState.Failed' \
    'raise WorkingDirectoryError.EmbeddedNul if sview_contains_byte\(lease.initial_path, 0\) or sview_contains_byte\(lease.current_path, 0\)' \
    'raise WorkingDirectoryError.EmbeddedNul if sview_contains_byte\(lease.pending_path, 0\)' \
    'raise WorkingDirectoryError.EmbeddedNul if sview_contains_byte\(session.request.initial_path, 0\)' \
    'raise WorkingDirectoryError.EmbeddedNul if sview_contains_byte\(path, 0\)' \
    'lease.state == WorkingDirectoryLeaseState.Held and lease.pending_path != ""' \
    'lease.state == WorkingDirectoryLeaseState.Changing or lease.state == WorkingDirectoryLeaseState.Restoring' \
    'lease.state == WorkingDirectoryLeaseState.Restored and' \
    'active_contexts'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsWorkingDirectory' \
    'typed_working_directory_contract_serializes_changes_and_restore' \
    'WorkingDirectoryEvent.Change' \
    'WorkingDirectoryEvent.ChangeAck' \
    'WorkingDirectoryEvent.RestoreAck' \
    'WorkingDirectoryError.ConcurrentOwner' \
    'WorkingDirectoryEvent.CancelAck' \
    'forged_identity' \
    'exhausted_rejected' \
    'nul_request_precedes_invalid_path' \
    'nul_change_precedes_invalid_path' \
    'nul_initial_precedes_invalid_path' \
    'nul_current_precedes_invalid_path' \
    'nul_pending_precedes_invalid_path'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsWorkingDirectory::WorkingDirectoryTable' "$docs"
rg -q 'ES-FS-006' "$ledger"

printf 'working directory audit: serialized bounded cwd ownership, acknowledgement, and restore edges are present\n'
