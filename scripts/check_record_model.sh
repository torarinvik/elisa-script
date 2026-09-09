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
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
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
    'RECORD_MAX_TEXT_BYTES' \
    'RECORD_MAX_FIELDS' \
    'record_text_length_valid' \
    'sview_contains_byte' \
    'record_fixed_widths_fit' \
    'try validate_record_stream_policy\(policy\)' \
    'try validate_record\(record, policy\)' \
    'else:' \
    'RecordContractError.FixedWidthOverflow' \
    'RecordContractError.InvalidFieldRange' \
    'RecordContractError.SchemaMissing' \
    'record_number == 0' \
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
    'validate_record_field' \
    'invalid_record_policy'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecord::RecordStreamPolicy' "$docs"
rg -q 'error\[RecordContractError\]' "$docs"
rg -q 'EsRecord::RecordStreamPolicy' "$ledger"
rg -q 'P11 record follow-up' "$plan"

printf 'record model audit: bounded separator, field, metadata, and range contracts are present\n'
