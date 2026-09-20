#!/usr/bin/env bash

# Compiler-free audit for bounded record field mutation/reconstruction.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_fields_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'record fields audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordFields:' "$model"
rg -q 'include "\.\./runtime/record_fields_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordFieldEditState of u8' \
    'const enum RecordFieldEditEvent of u8' \
    'struct RecordFieldEditPolicy:' \
    'struct RecordFieldEdit:' \
    'struct RecordFieldEditSession:' \
    'error RecordFieldEditError:' \
    'def validate_record_field_edit_session\(' \
    'def record_field_edit_reconstruct_length\(' \
    'def record_field_reconstruct\(' \
    'def advance_record_field_edit\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'Limits::EDITS' \
    'max_fields' \
    'max_output_bytes' \
    'output_separator' \
    'trailing_separator' \
    'allow_append' \
    'record_field_edit_bounded_add' \
    'RecordFieldEditError.InvalidFieldIndex' \
    'RecordFieldEditError.EditLimitExceeded' \
    'RecordFieldEditError.OutputLimitExceeded' \
    'RecordFieldEditError.AccountingInvalid' \
    'session.state == RecordFieldEditState.Planned and' \
    'session.state == RecordFieldEditState.Editing and' \
    'expected_output_bytes' \
    'RecordFieldEditEvent.Set' \
    'RecordFieldEditEvent.Reconstruct' \
    'RecordFieldEditState.Ready' \
    'join\(session.fields, session.policy.output_separator\)'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsRecordFields' \
    'typed_record_field_edit_contract_reconstructs_deterministically' \
    'RecordFieldEditEvent.Set' \
    'RecordFieldEditEvent.Reconstruct' \
    'record_field_reconstruct\(session\)' \
    'RecordFieldEditError.InvalidFieldIndex'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordFields::RecordFieldEditSession' "$docs"
rg -q 'ES-SCRIPT-030' "$ledger"

printf 'record fields audit: bounded mutation, deletion, append policy, and reconstruction are present\n'
