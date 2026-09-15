#!/usr/bin/env bash

# Compiler-free audit for structured task cleanup and join semantics.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/structured_task_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'structured task audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsStructuredTask:' "$model"
rg -q 'include "\.\./runtime/structured_task_model\.elisa"' "$ir"
for declaration in \
    'const enum StructuredScopeState of u8' \
    'const enum StructuredChildState of u8' \
    'const enum StructuredTaskEvent of u8' \
    'struct StructuredTaskPolicy:' \
    'struct StructuredChild:' \
    'struct StructuredTaskScope:' \
    'error StructuredTaskError:' \
    'def validate_structured_task_scope\(' \
    'def structured_task_spawn\(' \
    'def advance_structured_task\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'Limits::CHILDREN' \
    'Limits::CLEANUP_DEPTH' \
    'StructuredTaskEvent.RequestChildCancel' \
    'StructuredTaskEvent.EnterCleanup' \
    'StructuredTaskEvent.ChildCancelAck' \
    'StructuredTaskError.CancellationShielded' \
    'StructuredTaskError.JoinNotReady' \
    'StructuredChildState.Planned' \
    'StructuredTaskError.FailureCodeMissing' \
    'StructuredScopeState.Planned and' \
    'StructuredScopeState.Succeeded and' \
    'StructuredScopeState.Cancelled and' \
    'StructuredScopeState.Failed and' \
    'scope.state != StructuredScopeState.Running' \
    'StructuredTaskEvent.RequestCancel' \
    'StructuredChildState.Cleaning and' \
    'StructuredChildState.Cleaning and child.cleanup_depth'; do
    rg -q "$boundary" "$model"
done
rg -q 'child_state != StructuredChildState.CancelRequested and child_state != StructuredChildState.Cleaning' "$model"
rg -q 'forged_failed_planned' "$fixture_file"

for fixture_pattern in \
    'using EsStructuredTask' \
    'typed_structured_task_contract_shields_cleanup_before_join' \
    'StructuredTaskEvent.EnterCleanup' \
    'StructuredTaskError.CancellationShielded' \
    'still_shielded' \
    'StructuredScopeState.Cancelled' \
    'StructuredTaskError.CleanupDepthInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done
rg -q 'StructuredTaskError.JoinNotReady if child.state == StructuredChildState.Planned' "$model"
rg -q 'fail_pending_rejected' "$fixture_file"

rg -q 'EsStructuredTask::StructuredTaskScope' "$docs"
rg -q 'ES-SCRIPT-046' "$ledger"
rg -q 'P12 structured-concurrency follow-up' "$plan"

printf 'structured task audit: child cleanup shielding, cancellation, and join ordering are present\n'
