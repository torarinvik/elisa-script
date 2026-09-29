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
framer="$repo_root/src/runtime/csv_record_framer_model.elisa"
file_reader="$repo_root/src/runtime/csv_record_file_posix.elisa"
schema_csv="$repo_root/src/runtime/schema_csv_materializer.elisa"
schema_file_reader="$repo_root/src/runtime/schema_csv_file_posix.elisa"
file_writer="$repo_root/src/runtime/csv_record_file_writer_posix.elisa"

for required_file in "$model" "$ir" "$fixture" "$runtime_fixture" "$docs" "$parser" "$encoder" "$framer" "$file_reader" "$schema_csv" "$schema_file_reader" "$file_writer"; do
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

source_paths=("$model" "$ir" "$fixture" "$runtime_fixture" "$docs" "$parser" "$encoder" "$framer" "$file_reader" "$schema_csv" "$schema_file_reader" "$file_writer")
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
rg -Fq 'include "../runtime/csv_record_framer_model.elisa"' "$ir"
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
rg -Fq '`EsCsvRecordFramer::feed_csv_record_framer`' "$docs"
rg -Fq '`EsCsvRecordFilePosix::next_csv_record_file`' "$docs"
rg -Fq '`EsSchemaCsvFilePosix::next_schema_csv_file_record`' "$docs"
rg -Fq '`EsSchemaCsv::prepare_csv_schema_projection`' "$docs"
rg -Fq '`EsCsvRecordFileWriterPosix::write_csv_record_file`' "$docs"

for framer_pattern in \
    'module EsCsvRecordFramer:' \
    'CSV_RECORD_FRAMER_MAX_CHUNK_BYTES' \
    'def begin_csv_record_framer(' \
    'def feed_csv_record_framer(' \
    'def finish_csv_record_framer(' \
    'CsvStreamEvent.Byte'; do
    rg -Fq "$framer_pattern" "$framer"
done

rg -Fq 'include "../runtime/csv_record_file_writer_posix.elisa"' "$ir"
for file_writer_pattern in \
    'module EsCsvRecordFileWriterPosix:' \
    'const module Limits:' \
    'MAX_OUTPUT_BYTES: usize = FILE_STREAM_DEFAULT_MAX_BYTES' \
    'enum CsvRecordFileWriterMode of u8:' \
    'enum CsvRecordFileWriterState of u8:' \
    'def begin_csv_record_file_writer(' \
    'def write_csv_record_file(' \
    'def finish_csv_record_file_writer(' \
    'def abort_csv_record_file_writer(' \
    'file_stream_sync(writer.file)' \
    'writer.state <- CsvRecordFileWriterState.Failed'; do
    rg -Fq "$file_writer_pattern" "$file_writer"
done

for file_writer_fixture_pattern in \
    'csv_record_file_writer_streams_bounded_records_and_supports_append' \
    'using EsCsvRecordFileWriterPosix' \
    'CsvRecordFileWriterError.OutputLimitExceeded' \
    'CsvRecordFileWriterMode.Append' \
    'appended == 5 and finish_csv_record_file_writer(append_writer)'; do
    rg -Fq "$file_writer_fixture_pattern" "$runtime_fixture"
done

for framer_fixture_pattern in \
    'csv_record_framer_preserves_quoted_content_and_split_crlf' \
    'first_chunk.count == 0' \
    'third_chunk.count == 1' \
    'final_chunk.count == 1' \
    'blank_materialized.records[0].field_count == 0' \
    'record_limit_rejected' \
    'malformed_framer.state == CsvRecordFramerState.Failed'; do
    rg -Fq "$framer_fixture_pattern" "$runtime_fixture"
done

rg -Fq 'include "../runtime/csv_record_file_posix.elisa"' "$ir"
for file_reader_pattern in \
    'module EsCsvRecordFilePosix:' \
    'using EsCsv' \
    'CSV_RECORD_FILE_CHUNK_BYTES' \
    'def begin_csv_record_file_reader(' \
    'def next_csv_record_file(' \
    'def close_csv_record_file_reader(' \
    'FILE_STREAM_DEFAULT_MAX_BYTES - 1' \
    'if reader.source_bytes_read == input_limit:' \
    'return 1' \
    'input_limit + 1' \
    'file_stream_read_chunk(reader.file, buffer, capacity)' \
    'reader.pending_records <- try finish_csv_record_framer(reader.framer)' \
    'InputLimitExceeded'; do
    rg -Fq "$file_reader_pattern" "$file_reader"
done

for file_reader_fixture_pattern in \
    'csv_record_file_reader_streams_rows_and_rejects_over_limit_input' \
    'using EsCsvRecordFilePosix' \
    'not empty_result.has_record and empty_result.bytes.count == 0' \
    'first.bytes.count == CSV_RECORD_FILE_CHUNK_BYTES + 1' \
    'second.has_record and bytes_view(second.bytes)' \
    'exact_row.has_record' \
    'CsvRecordFileError.InputLimitExceeded'; do
    rg -Fq "$file_reader_fixture_pattern" "$runtime_fixture"
done

rg -Fq 'include "../runtime/schema_csv_file_posix.elisa"' "$ir"
for schema_csv_pattern in \
    'module EsSchemaCsv:' \
    'struct SchemaCsvProjection:' \
    'def prepare_csv_schema_projection(' \
    'def materialize_csv_schema_record_with_projection(' \
    'InvalidProjection'; do
    rg -Fq "$schema_csv_pattern" "$schema_csv"
done

for schema_file_reader_pattern in \
    'module EsSchemaCsvFilePosix:' \
    'using EsSchemaCsv' \
    'struct SchemaCsvFileReader:' \
    'def begin_schema_csv_file_reader(' \
    'def next_schema_csv_file_record(' \
    'def close_schema_csv_file_reader(' \
    'reader.projection <- projection' \
    'materialize_csv_schema_record_with_projection'; do
    rg -Fq "$schema_file_reader_pattern" "$schema_file_reader"
done

for schema_file_fixture_pattern in \
    'schema_csv_file_reader_streams_header_mapped_typed_rows' \
    'using EsSchemaCsvFilePosix' \
    'first.record.row_ordinal == 0' \
    'second.record.row_ordinal == 1' \
    'source_name: "name"' \
    'SchemaCsvValueKind.Integer' \
    'SchemaCsvMaterializeError.DuplicateHeader'; do
    rg -Fq "$schema_file_fixture_pattern" "$runtime_fixture"
done

printf 'csv model audit: bounded POSIX CSV reading and writing, schema-aware row streaming, chunk framing, and record encoding are present\n'
