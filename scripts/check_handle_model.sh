#!/usr/bin/env bash

# Compiler-free audit for host-handle ownership and transfer.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/handle_model.elisa"
resource_model="$repo_root/src/runtime/resource_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$resource_model" "$ir" "$fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'handle audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsHandle:' \
    'HANDLE_MAX_ENTRIES' \
    'const enum HostHandleState of u8:' \
    'const enum HostHandleEvent of u8:' \
    'struct HostHandle:' \
    'struct HostHandleTable:' \
    'error HostHandleError:' \
    'def validate_host_handle_table(' \
    'def host_handle_acquire(' \
    'def advance_host_handle('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'DuplicateResource' \
    'DuplicateRawHandle' \
    'OwnerMismatch' \
    'TransferInvalid' \
    'InvalidTransition' \
    'AccountingInvalid' \
    'HostHandleState.Closing' \
    'HostHandleState.Failed'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/handle_model.elisa"' "$ir"
rg -Fq 'using EsHandle' "$fixture"
for fixture_pattern in \
    'typed_host_handle_contract_tracks_raw_identity_transfer_and_cleanup' \
    'HostHandleEvent.Transfer' \
    'HostHandleEvent.CompleteClose' \
    'HostHandleEvent.Abandon' \
    'HostHandleError.DuplicateRawHandle'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsHandle supplies the host-handle table' "$docs"
rg -Fq 'ES-SCRIPT-006 | EsHandle' "$ledger"

printf 'handle audit: bounded raw identities, owner-token transfer, duplicate rejection, close/failure accounting, and abandonment are present\n'
