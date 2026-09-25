#!/usr/bin/env bash

# Compiler-free audit for bounded CSV/TSV field-span materialization.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/csv_materializer_model.elisa"
csv_model="$repo_root/src/runtime/csv_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
runtime_fixture="$repo_root/test/runtime/csv_empty_input_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$csv_model" "$ir" "$fixture" "$runtime_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'csv materializer audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsCsvMaterialize:' \
    'CSV_MATERIALIZER_MAX_FIELDS' \
    'CSV_MATERIALIZER_MAX_RECORDS' \
    'const enum CsvMaterializerState of u8:' \
    'const enum CsvMaterializerEvent of u8:' \
    'struct CsvFieldSpan:' \
    'struct CsvRecordSpan:' \
    'struct CsvMaterializer:' \
    'error CsvMaterializerError:' \
    'def validate_csv_materializer(' \
    'def csv_materialized_field(' \
    'def advance_csv_materializer('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'materializer_field_range_valid' \
    'materializer_raw_field_valid' \
    'materializer_record_terminator_at' \
    'materializer_complete_source_covered' \
    'FieldLayoutInvalid' \
    'RecordLayoutInvalid' \
    'try validate_csv_policy(materializer.policy)' \
    'sview_len(source) <= DATA_MAX_INPUT_BYTES' \
    'span.end - span.start <= DATA_MAX_FIELD_BYTES' \
    'record_field_cursor' \
    'FieldLimitExceeded' \
    'RecordLimitExceeded' \
    'FieldRangeInvalid' \
    'FieldOrderInvalid' \
    'RecordOrderInvalid' \
    'accounted_record_fields' \
    'materializer.next_field != materializer.fields.count' \
    'first_field > materializer.fields.count' \
    'record.first_field > materializer.fields.count' \
    'record.field_count > materializer.fields.count - record.first_field' \
    'if record.field_count == 0:' \
    'materializer_record_terminator_at(materializer, source_cursor)' \
    'materializer.state == CsvMaterializerState.Ready and' \
    'CsvMaterializerState.Building and materializer.state != CsvMaterializerState.Complete' \
    'SourceAccountingInvalid' \
    'EndNotReady'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/csv_materializer_model.elisa"' "$ir"
rg -Fq 'using EsCsvMaterialize' "$fixture"
for fixture_pattern in \
    'typed_csv_materializer_contract_preserves_bounded_field_spans' \
    'typed_csv_materializer_validates_crlf_boundaries_and_quoted_newlines' \
    'CsvLineEndingMode.CrLf' \
    'trailing_bytes_rejected' \
    'CsvMaterializerEvent.Field' \
    'CsvMaterializerEvent.Record' \
    'csv_materialized_field' \
    'CsvMaterializerError.FieldIndexInvalid'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

for fixture_pattern in \
    'csv_empty_input_and_blank_records_match_python_shape' \
    'empty_materializer.records.count == 0' \
    'blank_record_materializer.records.count == 1' \
    'blank_record_materializer.records[0].field_count == 0' \
    'quoted_empty_materializer.records.count == 1' \
    'mixed_materializer.fields.count == 2 and mixed_materializer.records.count == 3'; do
    rg -Fq "$fixture_pattern" "$runtime_fixture"
done

rg -Fq '`EsCsvMaterialize` gives CSV/TSV adapters a policy-bound borrowed-span' "$docs"
rg -Fq 'exact configured' "$docs"
rg -Fq 'ES-SCRIPT-009 | EsCsvMaterialize' "$ledger"

printf 'csv materializer audit: bounded spans, contiguous records, exact line endings, quote markers, shared ceilings, and validated slices are present\n'
