#!/usr/bin/env bash

# Compiler-free audit for bounded structured-data policies and decoder state.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/data_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'data model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsData:' \
    'DATA_MAX_INPUT_BYTES' \
    'DATA_MAX_DEPTH' \
    'const enum DataFormat of u8:' \
    'const enum DataDecoderState of u8:' \
    'const enum DataDecoderEvent of u8:' \
    'const enum CsvLineEndingMode of u8:' \
    'struct DataDecodeLimits:' \
    'struct JsonPolicy:' \
    'struct CsvPolicy:' \
    'struct DataDecoder:' \
    'error DataContractError:' \
    'def validate_data_decoder(' \
    'def advance_data_decoder(' \
    'def validate_json_policy(' \
    'def validate_csv_policy('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'InputLimitExceeded' \
    'TokenLimitExceeded' \
    'DepthLimitExceeded' \
    'RecordLimitExceeded' \
    'FieldLimitExceeded' \
    'FieldBytesLimitExceeded' \
    'data_limit_add(decoder.input_bytes, bytes_delta' \
    'data_limit_add(decoder.fields, fields_delta' \
    'field_bytes_delta > bytes_delta' \
    'raise DataContractError.DepthLimitExceeded if depth > decoder.limits.depth' \
    'OffsetAccountingInvalid' \
    'decoder.state == DataDecoderState.Ready' \
    'decoder.state == DataDecoderState.Complete' \
    'decoder.field_bytes' \
    'InvalidCsvPolicy' \
    'policy.line_ending == CsvLineEndingMode.ConfiguredByte and policy.record_separator == 0' \
    'data_csv_record_terminator_width' \
    'data_csv_record_terminator_contains' \
    'UnexpectedEnd' \
    'Cancelled'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/data_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_data_decoder_contract_bounds_json_and_csv_streams' \
    'typed_csv_stream_handles_explicit_line_ending_modes' \
    'CsvLineEndingMode.ConfiguredByte' \
    'CsvLineEndingMode.Lf' \
    'CsvLineEndingMode.CrLf' \
    'DataFormat.JsonLines' \
    'DataDecoderEvent.Begin' \
    'DataContractError.InvalidCsvPolicy' \
    'DataContractError.InputLimitExceeded' \
    'forged_ready' \
    'forged_complete' \
    'record_depth_rejected' \
    'record_overflow_rejected' \
    'decoder.offset == 15' \
    'decoder.fields == 4'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsData` is the format-neutral boundary' "$docs"
rg -Fq 'legacy configurable single-byte terminator' "$docs"
rg -Fq 'P8 structured-data follow-up' "$plan"

printf 'data model audit: bounded policies, explicit CSV line endings, and decoder state transitions are present\n'
