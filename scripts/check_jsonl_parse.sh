#!/usr/bin/env bash

# Compiler-free audit for the record-at-a-time JSON Lines parser boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
parser="$repo_root/src/runtime/jsonl_parse_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"

for required_file in "$parser" "$ir" "$fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'jsonl parse audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for contract in \
    'module EsJsonLinesParse:' \
    'struct JsonLinesReader:' \
    'struct JsonLinesReadResult:' \
    'error JsonLinesParseError:' \
    'def json_lines_record_is_whitespace(' \
    'def begin_json_lines_reader(' \
    'def validate_json_lines_reader(' \
    'def next_json_lines_document(' \
    'advance_json_stream(reader.stream, JsonStreamEvent.Byte, byte)' \
    'advance_json_stream(reader.stream, JsonStreamEvent.RecordEnd)' \
    'parse_json_document(lexed)' \
    'advance_data_decoder(reader.decoder, DataDecoderEvent.Token' \
    'advance_data_decoder(reader.decoder, DataDecoderEvent.Record' \
    'reader.failure_record_start <- reader.record_start' \
    'reader.stream.policy.allow_empty_records' \
    'JsonStreamState.Failed'; do
    rg -Fq "$contract" "$parser"
done

rg -Fq 'include "../runtime/jsonl_parse_model.elisa"' "$ir"
rg -Fq 'using EsJsonLinesParse' "$fixture"
for fixture_pattern in \
    'typed_json_lines_reader_returns_bounded_documents_one_record_at_a_time' \
    'begin_json_lines_reader("null\r\ntrue\n[1]", limits)' \
    'reader.decoder.records == 3 and reader.decoder.tokens == 5' \
    'empty_reader' \
    'begin_json_lines_reader("\r\nnull\n", limits, JsonPolicy{}, empty_policy)' \
    'whitespace_eof_reader' \
    'assert validate_json_lines_reader(limited_reader)' \
    'JsonLinesParseError.TokenLimitExceeded' \
    'failure_record_number == 3 and limited_reader.failure_record_start == 10' \
    'reader_stays_failed'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsJsonLinesParse::next_json_lines_document`' "$docs"

printf 'jsonl parse audit: bounded framing, cumulative budgets, and record-at-a-time JSON materialization are present\n'
