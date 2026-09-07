#!/usr/bin/env bash

# Compiler-free audit for runtime value ownership, borrowing, and reclamation.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/value_ownership_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'value ownership audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsValueOwnership:' "$model"
rg -q 'include "\.\./runtime/value_ownership_model\.elisa"' "$ir"
for declaration in \
    'const enum ValueOwnershipKind of u8' \
    'const enum ValueOwnershipState of u8' \
    'const enum BorrowLeaseState of u8' \
    'struct ValueLease:' \
    'struct BorrowLease:' \
    'struct ValueOwnershipLedger:' \
    'error ValueOwnershipError:' \
    'def validate_value_ownership\(' \
    'def value_ownership_acquire\(' \
    'def advance_value_ownership\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'VALUE_OWNERSHIP_MAX_VALUES' \
    'VALUE_OWNERSHIP_MAX_BORROWS' \
    'VALUE_OWNERSHIP_MAX_BYTES' \
    'ValueOwnershipKind.Linear' \
    'ValueOwnershipKind.BorrowedView' \
    'ValueOwnershipEvent.BeginBorrow' \
    'ValueOwnershipError.BorrowConflict' \
    'ValueOwnershipError.MoveNotReady' \
    'ValueOwnershipError.DropNotReady'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsValueOwnership' \
    'typed_value_ownership_contract_bounds_borrows_moves_and_reclamation' \
    'ValueOwnershipKind.Linear' \
    'ValueOwnershipEvent.EndBorrow' \
    'ValueOwnershipError.MoveNotReady' \
    'ledger.retained_bytes'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsValueOwnership::ValueOwnershipLedger' "$docs"
rg -q 'ES-SCRIPT-042' "$ledger"
rg -q 'P6 value-ownership follow-up' "$plan"

printf 'value ownership audit: bounded arena, borrow, move, and reclamation semantics are present\n'
