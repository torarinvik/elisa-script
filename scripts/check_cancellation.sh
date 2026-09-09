#!/usr/bin/env bash

# Compiler-free audit for cooperative cancellation checkpoints.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/cancellation_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'cancellation audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsCancellation:' "$model"
rg -q 'include "\.\./runtime/cancellation_model\.elisa"' "$ir"
for declaration in \
    'const enum CancellationTokenState of u8' \
    'const enum CancellationEvent of u8' \
    'const enum CancellationPoint of u8' \
    'struct CancellationPolicy:' \
    'struct CancellationToken:' \
    'struct CancellationLedger:' \
    'error CancellationError:' \
    'def validate_cancellation_ledger\(' \
    'def cancellation_register\(' \
    'def poll_cancellation\(' \
    'def advance_cancellation\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'CANCELLATION_MAX_TOKENS' \
    'CANCELLATION_MAX_CHILDREN' \
    'CANCELLATION_MAX_POLLS' \
    'CANCELLATION_MAX_REASON_BYTES' \
    'CancellationEvent.Propagate' \
    'CancellationEvent.Acknowledge' \
    'CancellationPoint.HostBeforeBlock' \
    'CancellationError.HostBlockDenied' \
    'HostBlockDenied if point == CancellationPoint.HostBeforeBlock' \
    'CancellationError.ParentCycle' \
    'parent_index: usize = cancellation_index' \
    'CancellationError.PollLimitExceeded' \
    'token.state == CancellationTokenState.Acknowledged' \
    'CancellationPoint.HostAfterBlock'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsCancellation' \
    'typed_cancellation_contract_polls_and_denies_blocking_work' \
    'CancellationPoint.VmSafePoint' \
    'CancellationPoint.HostBeforeBlock' \
    'CancellationError.HostBlockDenied'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsCancellation::CancellationLedger' "$docs"
rg -q 'ES-SCRIPT-044' "$ledger"
rg -q 'P6 cooperative-cancellation follow-up' "$plan"

printf 'cancellation audit: bounded tokens, safe-point polling, and host blocking denial are present\n'
