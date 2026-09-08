#!/usr/bin/env bash

# Compiler-free audit for record-stream hook ordering.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_lifecycle_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'record lifecycle audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordLifecycle:' "$model"
rg -q 'include "\.\./runtime/record_lifecycle_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordLifecycleState of u8' \
    'const enum RecordLifecycleEvent of u8' \
    'struct RecordLifecyclePolicy:' \
    'struct RecordLifecycleSession:' \
    'error RecordLifecycleError:' \
    'def validate_record_lifecycle\(' \
    'def advance_record_lifecycle\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'RECORD_LIFECYCLE_MAX_FILES' \
    'RECORD_LIFECYCLE_MAX_RECORDS' \
    'record_lifecycle_name_valid' \
    'session.file_open and not record_lifecycle_name_valid\(session.current_file\)' \
    'session.file_open and session.file_count == 0' \
    'session.record_count != 0 and session.file_count == 0' \
    'RecordLifecycleError.FileNotOpen' \
    'RecordLifecycleError.RecordNotOpen' \
    'RecordLifecycleError.EmptyFileNotAllowed' \
    'RecordLifecycleEvent.RecordBegin' \
    'RecordLifecycleEvent.FileEnd' \
    'RecordLifecycleEvent.Cancel'; do
    rg -q "$boundary" "$model"
done
rg -q -U 'elif event == RecordLifecycleEvent.RecordEnd:\n                raise RecordLifecycleError.InvalidState if session.state != RecordLifecycleState.Running\n                raise RecordLifecycleError.RecordNotOpen if not session.record_open\n                raise RecordLifecycleError.RecordLimitExceeded if session.record_count >= session.policy.max_records' "$model"

for fixture_pattern in \
    'using EsRecordLifecycle' \
    'typed_record_lifecycle_contract_orders_file_and_record_hooks' \
    'RecordLifecycleEvent.FileBegin' \
    'RecordLifecycleEvent.RecordEnd' \
    'RecordLifecycleError.FileNotOpen' \
    'overflow_end'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordLifecycle::RecordLifecycleSession' "$docs"
rg -q 'ES-SCRIPT-026' "$ledger"
rg -q 'P11 lifecycle follow-up' "$plan"

printf 'record lifecycle audit: bounded file/record hook ordering and cleanup are present\n'
