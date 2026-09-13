#!/usr/bin/env bash

# Compiler-free audit for bounded cross-task value/handler ownership transfer.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/task_transfer_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'task transfer audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsTaskTransfer:' "$model"
rg -q 'include "\.\./runtime/task_transfer_model\.elisa"' "$ir"
for declaration in \
    'const enum TaskTransferState of u8' \
    'const enum TaskTransferValueKind of u8' \
    'const enum TaskTransferMode of u8' \
    'struct TaskTransferResource:' \
    'struct TaskTransferRequest:' \
    'struct TaskTransferSession:' \
    'error TaskTransferError:' \
    'def validate_task_transfer\(' \
    'def advance_task_transfer\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'Limits::ITEMS' \
    'Limits::BYTES' \
    'Limits::BORROW_TICKS' \
    'TaskTransferMode.Copy' \
    'TaskTransferMode.Move' \
    'TaskTransferMode.Borrow' \
    'TaskTransferError.DuplicateResource' \
    'derived_admitted_items' \
    'derived_committed_items' \
    'derived_admitted_bytes' \
    'TaskTransferError.CommitNotReady' \
    'TaskTransferState.Committed' \
    'TaskTransferState.Committing' \
    'TaskTransferState.Planned and' \
    'TaskTransferState.Validating and' \
    'session.state == TaskTransferState.Committed'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsTaskTransfer' \
    'typed_task_transfer_contract_preserves_move_and_borrow_ownership' \
    'TaskTransferValueKind.Linear' \
    'TaskTransferValueKind.HandlerContext' \
    'TaskTransferError.InvalidMode' \
    'task_transfer_owner' \
    'TaskTransferError.ItemStateInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsTaskTransfer::TaskTransferSession' "$docs"
rg -q 'ES-SCRIPT-040' "$ledger"
rg -q 'P12 ownership-transfer follow-up' "$plan"

printf 'task transfer audit: bounded copy/move/borrow ownership protocol is present\n'
