#!/usr/bin/env bash

# Compiler-free audit for bounded record field mutation/reconstruction.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_fields_model.elisa"
adapter="$repo_root/src/runtime/record_field_edit_adapter_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
adapter_fixture="$repo_root/test/runtime/record_field_edit_adapter_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$adapter" "$ir" "$fixture_file" "$adapter_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'record fields audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordFields:' "$model"
rg -q '^module EsRecordFieldEditAdapter:' "$adapter"
rg -q 'include "\.\./runtime/record_fields_model\.elisa"' "$ir"
rg -q 'include "\.\./runtime/record_field_edit_adapter_model\.elisa"' "$ir"
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

for adapter_boundary in \
    'def record_field_edit_session_from_fields\(' \
    'def record_field_edit_session_from_regex_spans\(' \
    'split_record_fields_from_regex_spans' \
    'def record_field_reconstruct_record\(' \
    'record_field_edit_adapter_mode_supported' \
    'record_field_edit_adapter_fields_match' \
    'record.separator if record_policy.preserve_separator' \
    'record_field_edit_reconstruct_length(session)' \
    'RecordFieldEditError.OutputLimitExceeded'; do
    rg -q "$adapter_boundary" "$adapter"
done

validated_transfer_body="$(sed -n '/def record_field_edit_session_from_validated_fields(/,/^        def /p' "$adapter")"
if printf '%s\n' "$validated_transfer_body" | rg -q 'validate_record\(|validate_record_field\('; then
    printf 'record fields audit: validated field transfer must not rescan the owning record\n' >&2
    exit 1
fi

reconstruct_record_body="$(sed -n '/def record_field_reconstruct_record(/,/^        def /p' "$adapter")"
planned_bytes_line="$(printf '%s\n' "$reconstruct_record_body" | awk '/record_field_edit_reconstruct_length\(session\)/ { print NR; exit }')"
content_materialize_line="$(printf '%s\n' "$reconstruct_record_body" | awk '/record_field_reconstruct\(session\)/ { print NR; exit }')"
if [[ -z "$planned_bytes_line" || -z "$content_materialize_line" || "$planned_bytes_line" -ge "$content_materialize_line" ]]; then
    printf 'record fields audit: record size must be checked before allocating reconstructed content\n' >&2
    exit 1
fi

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

for adapter_fixture_pattern in \
    'scanned_fields_edit_and_reconstruct_with_explicit_separators' \
    'record_edit_adapter_preserves_consumed_separator_and_enforces_record_limit' \
    'reconstructed == "a|changed|\\n"' \
    'record_field_reconstruct_record' \
    'RecordFieldEditError.OutputLimitExceeded' \
    'record_edit_adapter_rejects_incomplete_scanner_output_and_unwired_modes' \
    'record_edit_adapter_reconstructs_regex_scanned_fields' \
    'record_edit_adapter_rejects_invalid_regex_spans_and_field_overflow' \
    'RecordFieldScanError.InvalidSeparatorSpan' \
    'RecordFieldScanError.FieldLimitExceeded' \
    'RecordFieldScanError.FieldSetMismatch' \
    'RecordFieldMode.FixedWidth'; do
    rg -Fq "$adapter_fixture_pattern" "$adapter_fixture"
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
rg -q 'record_field_reconstruct_record' "$docs"
rg -q 'FieldSetMismatch' "$docs"
rg -q 'ES-SCRIPT-030' "$ledger"

printf 'record fields audit: bounded mutation, deletion, append policy, and reconstruction are present\n'
