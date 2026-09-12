#!/usr/bin/env bash

# Compiler-free audit for the record-at-a-time JSON Lines parser boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
parser="$repo_root/src/runtime/jsonl_parse_model.elisa"
stream="$repo_root/src/runtime/json_stream_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"

for required_file in "$parser" "$stream" "$ir" "$fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'jsonl parse audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for boundary_contract in \
    'const enum JsonLineBoundaryMode of u8:' \
    'BalancedContainers' \
    'PhysicalLines' \
    'record_boundary: JsonLineBoundaryMode = JsonLineBoundaryMode.BalancedContainers' \
    'policy.record_boundary == JsonLineBoundaryMode.BalancedContainers or policy.record_boundary == JsonLineBoundaryMode.PhysicalLines' \
    'def json_stream_byte_is_boundary_candidate(' \
    'JsonStreamError.UnterminatedString if session.in_string or session.escaped' \
    'JsonStreamError.UnterminatedValue if session.policy.record_boundary == JsonLineBoundaryMode.PhysicalLines and session.depth != 0'; do
    rg -Fq "$boundary_contract" "$stream"
done
[[ "$(rg -Fc 'record_boundary: framing.record_boundary' "$parser")" == 2 ]]

for contract in \
    'module EsJsonLinesParse:' \
    'struct JsonLinesReader:' \
    'struct JsonLinesReadResult:' \
    'struct JsonLinesChunkReader:' \
    'struct JsonLinesFeedResult:' \
    'error JsonLinesParseError:' \
    'def json_lines_record_is_whitespace(' \
    'def begin_json_lines_reader(' \
    'def validate_json_lines_reader(' \
    'def next_json_lines_document(' \
    'def feed_json_lines_chunk(' \
    'reader.stream.input_bytes - reader.decoder.input_bytes != reader.stream.record_bytes' \
    'JsonLinesFeedOutcome.NeedInput' \
    'advance_json_stream(reader.stream, JsonStreamEvent.Byte, byte)' \
    'advance_json_stream(reader.stream, JsonStreamEvent.RecordEnd)' \
    'parse_json_document(lexed)' \
    'advance_data_decoder(reader.decoder, DataDecoderEvent.Token' \
    'advance_data_decoder(reader.decoder, DataDecoderEvent.Record' \
    'reader.failure_record_start <- reader.record_start' \
    'reader.stream.policy.allow_empty_records' \
    'json_stream_byte_is_boundary_candidate(reader.stream, byte)' \
    'record_boundary: framing.record_boundary' \
    'JsonStreamState.Failed'; do
    rg -Fq "$contract" "$parser"
done

rg -Fq 'include "../runtime/jsonl_parse_model.elisa"' "$ir"
rg -Fq 'using EsJsonLinesParse' "$fixture"
for fixture_pattern in \
    'typed_json_lines_reader_returns_bounded_documents_one_record_at_a_time' \
    'begin_json_lines_chunk_reader(limits)' \
    'second_chunk.outcome == JsonLinesFeedOutcome.Document and second_chunk.consumed_bytes == 3' \
    'final_record.record_number == 2 and final_record.source_offset == 5' \
    'final_delimiter_suffix.outcome == JsonLinesFeedOutcome.Document and final_delimiter_suffix.consumed_bytes == 5' \
    'final_delimiter_reader.stream.state == JsonStreamState.Complete' \
    'final_delimiter_wrong_suffix_rejected' \
    'split_crlf.outcome == JsonLinesFeedOutcome.NeedInput and split_crlf.consumed_bytes == 1' \
    'empty_chunk_result.record_number == 2 and empty_chunk_result.source_offset == 2 and empty_chunk_result.consumed_bytes == 6' \
    'chunk_limited_reader.failure_record_number == 2 and chunk_limited_reader.failure_record_start == 5' \
    'begin_json_lines_reader("null\r\ntrue\n[1]", limits)' \
    'reader.decoder.records == 3 and reader.decoder.tokens == 5' \
    'empty_reader' \
    'begin_json_lines_reader("\r\nnull\n", limits, JsonPolicy{}, empty_policy)' \
    'whitespace_eof_reader' \
    'assert validate_json_lines_reader(limited_reader)' \
    'JsonLinesParseError.TokenLimitExceeded' \
    'failure_record_number == 3 and limited_reader.failure_record_start == 10' \
    'reader_stays_failed' \
    'JSON_LINES_PARSE_FORMAT_VERSION == 2' \
    'balanced_multiline_reader' \
    'JsonLineBoundaryMode.PhysicalLines' \
    'physical_multiline_reader' \
    'physical_string_reader' \
    'physical_chunk_reader' \
    'physical_chunk_string_reader' \
    'physical_empty_reader'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsJsonLinesParse::next_json_lines_document`' "$docs"

printf 'jsonl parse audit: bounded framing, cumulative budgets, and record-at-a-time chunk parsing are present\n'
