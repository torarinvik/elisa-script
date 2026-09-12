#!/usr/bin/env bash

# Compiler-free source audit for the bounded POSIX JSONL file adapter.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
adapter="$repo_root/src/runtime/jsonl_file_posix.elisa"
parser="$repo_root/src/runtime/jsonl_parse_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"

for required_file in "$adapter" "$parser" "$ir" "$fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'jsonl file audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for contract in \
    'module EsJsonLinesFilePosix:' \
    'using EsJsonLinesParse' \
    'using EsRuntime' \
    'const JSON_LINES_FILE_CHUNK_BYTES: usize = 16384' \
    'const JSON_LINES_FILE_MAX_INPUT_BYTES: usize = FILE_STREAM_DEFAULT_MAX_BYTES - 1' \
    'const enum JsonLinesFileReaderState of u8:' \
    'struct JsonLinesFileReader:' \
    'const enum JsonLinesFileAction of u8:' \
    'error JsonLinesFileError:' \
    'machine over json_lines_file_action(reader) while true:' \
    'def json_lines_file_read_capacity(' \
    'def json_lines_file_reader_state_valid(' \
    'def begin_json_lines_file_reader(' \
    'def next_json_lines_file_document(' \
    'def close_json_lines_file_reader(' \
    'FileStreamMode.ReadBinary, effective_input_bytes + 1, FileStreamEncoding.Bytes' \
    'file_stream_read_chunk(reader.file, buffer, capacity)' \
    'feed_json_lines_chunk(reader.parser, json_lines_file_chunk_view(reader))' \
    'feed_json_lines_chunk(reader.parser, "", true)' \
    'FILE_STREAM_DEFAULT_MAX_BYTES - 1' \
    'JsonStreamError.InputLimitExceeded' \
    'file_stream_cleanup_commit(reader.cleanup, reader.file)' \
    'file_stream_cleanup_abort(reader.cleanup, reader.file)'; do
    rg -Fq "$contract" "$adapter"
done

rg -Fq 'include "../runtime/jsonl_file_posix.elisa"' "$ir"
! rg -q 'file_stream_read_line(_mode)?\(' "$adapter"
for fixture_pattern in \
    'typed_json_lines_file_adapter_uses_bounded_owned_chunks' \
    'JSON_LINES_FILE_CHUNK_BYTES == 16384' \
    'JSON_LINES_FILE_MAX_INPUT_BYTES + 1 == FILE_STREAM_DEFAULT_MAX_BYTES' \
    'JsonLinesFileReaderState.Failed != JsonLinesFileReaderState.Closed'; do
    rg -Fq "$fixture_pattern" "$fixture"
done
rg -Fq 'begin_json_lines_file_reader' "$docs"
rg -Fq 'close_json_lines_file_reader' "$docs"

printf 'jsonl file audit: bounded FileStream ownership and one-document chunk feeding are present\n'
