#!/usr/bin/env bash

# Compiler-free audit for the bounded Perl/AWK-style record contract.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_model.elisa"
field_scanner="$repo_root/src/runtime/record_field_scan_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
scanner_fixture="$repo_root/test/runtime/record_field_scan_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$field_scanner" "$ir" "$fixture_file" "$scanner_fixture" "$docs" "$ledger"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'record model audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q '^module EsRecord:' "$model"
rg -q '^module EsRecordFieldScan:' "$field_scanner"
rg -q 'include "\.\./runtime/record_model\.elisa"' "$ir"
rg -q 'include "\.\./runtime/record_field_scan_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordSeparatorMode of u8' \
    'const enum RecordFieldMode of u8' \
    'struct RecordStreamPolicy:' \
    'struct Record:' \
    'struct RecordField:' \
    'error RecordContractError:' \
    'def validate_record_stream_policy\(' \
    'def validate_record\(' \
    'def validate_record_field\('; do
    rg -q "$declaration" "$model"
done

for scanner_boundary in \
    'def split_record_fields\(' \
    'record_field_scan_ascii_whitespace' \
    'record_field_scan_separator_at' \
    'RecordFieldMode.Whole' \
    'RecordFieldMode.Whitespace' \
    'RecordFieldMode.Literal' \
    'RecordFieldMode.FixedWidth' \
    'RecordFieldScanError.FieldLimitExceeded' \
    'RecordFieldScanError.FixedWidthRemainder' \
    'RecordFieldScanError.UnsupportedMode'; do
    rg -q "$scanner_boundary" "$field_scanner"
done

for boundary in \
    'Limits::TEXT_BYTES' \
    'Limits::FIELDS' \
    'record_text_length_valid' \
    'sview_contains_byte' \
    'record_fixed_widths_fit' \
    'record_fixed_widths_fit\(policy.fixed_widths, policy.max_fields, policy.max_record_bytes\)' \
    'try validate_record_stream_policy\(policy\)' \
    'try validate_record\(record, policy\)' \
    'else:' \
    'RecordContractError.FixedWidthOverflow' \
    'RecordContractError.InvalidFieldRange' \
    'RecordContractError.SchemaMissing' \
    'record_number == 0' \
    'not field.present and field.value != ""' \
    'field.value != record.raw'; do
    rg -q "$boundary" "$model"
done

for scanner_fixture_pattern in \
    'record_scanner_materializes_whitespace_literal_and_whole_fields' \
    'fixed_width_record_scanner_marks_absent_columns_and_rejects_remainders' \
    'unicode_fields[1].start_byte == 3' \
    'literal_fields.count == 4' \
    'literal_empty_fields.count == 0' \
    'advance_record_materializer' \
    'validate_record_materializer' \
    'not fields[2].present' \
    'RecordFieldScanError.FieldLimitExceeded' \
    'RecordFieldScanError.UnsupportedMode'; do
    rg -Fq "$scanner_fixture_pattern" "$scanner_fixture"
done

for fixture_pattern in \
    'typed_record_stream_contract_is_bounded_and_explicit' \
    'RecordSeparatorMode.Regex' \
    'RecordFieldMode.FixedWidth' \
    'RecordFieldMode.Schema' \
    'RecordContractError.InvalidSeparator' \
    'RecordContractError.FixedWidthMalformed' \
    'fixed_record_limit' \
    'validate_record_field' \
    'invalid_record_policy'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecord::RecordStreamPolicy' "$docs"
rg -q 'EsRecordFieldScan::split_record_fields' "$docs"
rg -q 'error\[RecordContractError\]' "$docs"
rg -q 'EsRecord::RecordStreamPolicy' "$ledger"
rg -q 'EsRecordFieldScan' "$ledger"

printf 'record model audit: bounded separator, field, metadata, and range contracts are present\n'
