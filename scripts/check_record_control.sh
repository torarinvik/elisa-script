#!/usr/bin/env bash

# Compiler-free audit for explicit next/nextfile/exit record control.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_control_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'record control audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordControl:' "$model"
rg -q 'include "\.\./runtime/record_control_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordControlState of u8' \
    'const enum RecordControlEvent of u8' \
    'struct RecordControlPolicy:' \
    'struct RecordControlSession:' \
    'error RecordControlError:' \
    'def validate_record_control\(' \
    'def advance_record_control\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'RECORD_CONTROL_MAX_FILES' \
    'RECORD_CONTROL_MAX_RECORDS' \
    'RecordControlEvent.NextRecord' \
    'RecordControlEvent.NextFile' \
    'RecordControlEvent.Exit' \
    'RecordControlError.RecordNotOpen' \
    'RecordControlError.RecordLimitExceeded if session.record_count >= session.policy.max_records' \
    'RecordControlError.FileNotClosed' \
    'session.file_open and session.file_count == 0' \
    'session.record_count != 0 and session.file_count == 0' \
    'RecordControlState.Planned' \
    'RecordControlState.RecordSkipped' \
    'RecordControlState.FileSkipped' \
    'RecordControlState.Exited'; do
    rg -q "$boundary" "$model"
done
rg -q -U 'elif event == RecordControlEvent.RecordEnd:\n                raise RecordControlError.InvalidState if session.state != RecordControlState.Running\n                raise RecordControlError.RecordNotOpen if not session.record_open\n                raise RecordControlError.RecordLimitExceeded if session.record_count >= session.policy.max_records' "$model"

for fixture_pattern in \
    'using EsRecordControl' \
    'typed_record_control_contract_makes_next_and_exit_explicit' \
    'RecordControlEvent.NextRecord' \
    'RecordControlEvent.NextFile' \
    'RecordControlEvent.Exit' \
    'RecordControlError.FileNotOpen' \
    'forged_skip' \
    'overflow_end_rejected'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordControl::RecordControlSession' "$docs"
rg -q 'ES-SCRIPT-029' "$ledger"
rg -q 'P11 control follow-up' "$plan"

printf 'record control audit: bounded next/nextfile/exit scope transitions are present\n'
