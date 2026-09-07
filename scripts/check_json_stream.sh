#!/usr/bin/env bash

# Compiler-free audit for bounded JSON/JSONL framing.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/json_stream_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'json stream audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsJsonStream:' "$model"
rg -q 'include "\.\./runtime/json_stream_model\.elisa"' "$ir"
for declaration in \
    'const enum JsonStreamState of u8' \
    'const enum JsonStreamEvent of u8' \
    'struct JsonStreamPolicy:' \
    'struct JsonStreamSession:' \
    'error JsonStreamError:' \
    'def validate_json_stream\(' \
    'def advance_json_stream\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'JSON_STREAM_MAX_INPUT_BYTES' \
    'JSON_STREAM_MAX_RECORD_BYTES' \
    'JSON_STREAM_MAX_RECORDS' \
    'JSON_STREAM_MAX_DEPTH' \
    'json_stream_finish_record' \
    'in_string' \
    'escaped' \
    'JsonStreamError.DepthUnderflow' \
    'JsonStreamError.MismatchedDelimiter' \
    'container_stack' \
    'JsonStreamError.UnterminatedString' \
    'JsonStreamError.UnterminatedValue' \
    'JsonStreamEvent.RecordEnd' \
    'JsonStreamEvent.Cancel' \
    'JsonStreamState.Complete'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsJsonStream' \
    'typed_json_stream_contract_frames_records_and_depth' \
    'JsonStreamEvent.Byte' \
    'JsonStreamEvent.End' \
    'JsonStreamError.UnterminatedValue' \
    'JsonStreamError.RecordBytesLimitExceeded'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsJsonStream::JsonStreamSession' "$docs"
rg -q 'ES-SCRIPT-036' "$ledger"
rg -q 'P8 JSONL-stream follow-up' "$plan"

printf 'json stream audit: bounded JSONL framing, string/escape tracking, and depth limits are present\n'
