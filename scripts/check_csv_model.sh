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
parser="$repo_root/src/runtime/csv_parser_model.elisa"
encoder="$repo_root/src/runtime/csv_encode_model.elisa"

for required_file in "$model" "$ir" "$fixture" "$runtime_fixture" "$docs" "$parser" "$encoder"; do
    [[ -f "$required_file" ]] || { printf 'csv model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

# Keep the shell oracle within the same explicit resource envelope as the
# bounded Elisascript candidate before invoking rg on any source.
source_bytes() {
    local source_path="$1"
    local measured
    if ! measured="$(/usr/bin/stat -f%z "$source_path" 2>/dev/null)"; then
        return 1
    fi
    [[ "$measured" =~ ^[0-9]+$ ]] || return 1
    printf '%s' "$measured"
}

source_paths=("$model" "$ir" "$fixture" "$runtime_fixture" "$docs" "$parser" "$encoder")
total_bytes=0
for source_path in "${source_paths[@]}"; do
    source_size="$(source_bytes "$source_path")" || { printf 'csv model audit: missing %s\n' "$source_path" >&2; exit 1; }
    if (( source_size > 16777216 || source_size > 33554432 - total_bytes )); then
        printf 'csv model audit: source exceeds audit limit: %s\n' "$source_path" >&2
        exit 2
    fi
    total_bytes=$((total_bytes + source_size))
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
    'mixed_stream.records == 3 and mixed_stream.fields_total == 2' \
    'csv_source_parser_materializes_quoted_fields_blank_rows_and_crlf' \
    'parsed.records.count == 3 and parsed.fields.count == 4' \
    'assert failure == CsvContractError.UnexpectedQuote'; do
    rg -Fq "$fixture_pattern" "$runtime_fixture"
done

rg -Fq '`EsCsv`' "$docs"
rg -Fq '`EsCsvParser::parse_csv_materializer`' "$docs"
for parser_pattern in \
    'module EsCsvParser:' \
    'def parse_csv_materializer(' \
    'advance_csv_stream(stream, CsvStreamEvent.Byte, byte)' \
    'CsvStreamState.PendingRecordTerminator' \
    'previous_records' \
    'materializer.fields.count != stream.fields_total' \
    'materializer.records.count != stream.records'; do
    rg -Fq "$parser_pattern" "$parser"
done

for encoder_pattern in \
    'module EsCsvEncode:' \
    'const enum CsvEncodePhase of u8:' \
    'OutputLimitExceeded' \
    'def encode_csv_record(' \
    'csv_policy_record_terminator_width(policy)'; do
    rg -Fq "$encoder_pattern" "$encoder"
done

for encoder_fixture_pattern in \
    'csv_record_encoder_preserves_cells_under_explicit_dialects' \
    'one_empty_field' \
    'custom_escape' \
    'exact_limit' \
    'over_limit_rejected'; do
    rg -Fq "$encoder_fixture_pattern" "$runtime_fixture"
done

rg -Fq '`EsCsvEncode::encode_csv_record`' "$docs"

printf 'csv model audit: bounded CSV record encoding, source parsing, quote-aware transitions, and explicit line endings are present\n'
