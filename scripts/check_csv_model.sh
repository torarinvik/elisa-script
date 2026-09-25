#!/usr/bin/env bash

# Compiler-free audit for quote-aware CSV/TSV streaming.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/csv_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
runtime_fixture="$repo_root/test/runtime/csv_empty_input_test.elisa"
docs="$repo_root/docs/ir.md"

for required_file in "$model" "$ir" "$fixture" "$runtime_fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'csv model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsCsv:' \
    'using EsData' \
    'const module Limits:' \
    'const enum CsvStreamState of u8:' \
    'PendingRecordTerminator' \
    'const enum CsvStreamEvent of u8:' \
    'struct CsvStream:' \
    'error CsvContractError:' \
    'def validate_csv_stream(' \
    'def advance_csv_stream('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'Limits::RECORDS' \
    'Limits::FIELDS' \
    'Limits::FIELD_BYTES' \
    'InputLimitExceeded' \
    'FieldBytesLimitExceeded' \
    'UnexpectedQuote' \
    'UnexpectedCharacterAfterQuote' \
    'InvalidRecordTerminator' \
    'UnexpectedEnd' \
    'AccountingInvalid' \
    'Cancelled' \
    'field_started' \
    'stream.fields_in_record == 0 and stream.field_bytes == 0 and not stream.field_started' \
    'raise CsvContractError.RecordLimitExceeded if stream.records >= stream.limits.records'; do
    rg -Fq "$boundary" "$model"
done

if rg -Fq 'stream.fields_total < stream.records' "$model"; then
    printf '%s\n' 'csv model audit: zero-field blank records were incorrectly rejected' >&2
    exit 1
fi

rg -Fq 'include "../runtime/csv_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_csv_stream_contract_preserves_quotes_and_bounded_rows' \
    'typed_csv_stream_handles_explicit_line_ending_modes' \
    'CsvLineEndingMode.CrLf' \
    'CsvStreamState.PendingRecordTerminator' \
    'CsvStreamEvent.Byte' \
    'CsvContractError.UnexpectedEnd' \
    'assert limited.fields_total == 1' \
    'assert byte_rejected.input_bytes == 1'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

for fixture_pattern in \
    'csv_empty_input_and_blank_records_match_python_shape' \
    'empty_stream.records == 0' \
    'blank_record_stream.records == 1 and blank_record_stream.fields_total == 0' \
    'quoted_empty_stream.records == 1 and quoted_empty_stream.fields_total == 1' \
    'mixed_stream.records == 3 and mixed_stream.fields_total == 2'; do
    rg -Fq "$fixture_pattern" "$runtime_fixture"
done

rg -Fq '`EsCsv`' "$docs"

printf 'csv model audit: quote-aware bounded stream transitions and explicit line endings are present\n'
