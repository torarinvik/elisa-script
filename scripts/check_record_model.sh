#!/usr/bin/env bash

# Compiler-free audit for the bounded Perl/AWK-style record contract.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'record model audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q '^module EsRecord:' "$model"
rg -q 'include "\.\./runtime/record_model\.elisa"' "$ir"
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
rg -q 'error\[RecordContractError\]' "$docs"
rg -q 'EsRecord::RecordStreamPolicy' "$ledger"

printf 'record model audit: bounded separator, field, metadata, and range contracts are present\n'
