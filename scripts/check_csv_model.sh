#!/usr/bin/env bash

# Compiler-free audit for quote-aware CSV/TSV streaming.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/csv_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"

for required_file in "$model" "$ir" "$fixture" "$docs"; do
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
    'stream.fields_total < stream.records' \
    'Cancelled' \
    'raise CsvContractError.RecordLimitExceeded if stream.records >= stream.limits.records'; do
    rg -Fq "$boundary" "$model"
done

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

rg -Fq '`EsCsv`' "$docs"

printf 'csv model audit: quote-aware bounded stream transitions and explicit line endings are present\n'
