#!/usr/bin/env bash

# Compiler-free audit for the bounded advisory file-lock contract.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/file_lock_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'file lock audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsFileLock:' "$model"
rg -q 'include "\.\./runtime/file_lock_model\.elisa"' "$ir"
for declaration in \
    'const enum FileLockMode of u8' \
    'const enum FileLockWaitMode of u8' \
    'const enum FileLockState of u8' \
    'const enum FileLockEvent of u8' \
    'struct FileLockPolicy:' \
    'struct FileLockTable:' \
    'struct FileLockSession:' \
    'error FileLockError:' \
    'def validate_file_lock_table\(' \
    'def validate_file_lock_session\(' \
    'def advance_file_lock\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'FILE_LOCK_MAX_LEASES' \
    'FILE_LOCK_MAX_PATH_BYTES' \
    'FILE_LOCK_MAX_ATTEMPTS' \
    'file_lock_conflicts' \
    'FileLockMode.Shared' \
    'FileLockMode.Exclusive' \
    'FileLockWaitMode.NonBlocking' \
    'FileLockWaitMode.Bounded' \
    'FileLockEvent.ReleaseAck' \
    'FileLockEvent.CancelAck' \
    'FileLockError.Conflict' \
    'FileLockError.WouldBlock' \
    'FileLockError.DuplicateOwnerPath' \
    'table.next_lease_id <= lease.lease_id' \
    'active_leases' \
    'FileLockLeaseState.Failed'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsFileLock' \
    'typed_file_lock_contract_distinguishes_shared_exclusive_and_waits' \
    'FileLockMode.Shared' \
    'FileLockMode.Exclusive' \
    'FileLockError.Conflict' \
    'FileLockError.WouldBlock' \
    'FileLockEvent.ReleaseAck' \
    'FileLockEvent.CancelAck' \
    'forged_identity'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsFileLock::FileLockTable' "$docs"
rg -q 'ES-FS-004' "$ledger"
rg -q 'P9 file-lock follow-up' "$plan"

printf 'file lock audit: bounded advisory shared/exclusive ownership and cleanup edges are present\n'
