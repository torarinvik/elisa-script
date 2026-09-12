#!/usr/bin/env bash

# Compiler-free audit for typed structured-data schema binding.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/schema_model.elisa"
json_model="$repo_root/src/runtime/json_model.elisa"
json_materializer="$repo_root/src/runtime/schema_json_materializer.elisa"
csv_materializer="$repo_root/src/runtime/schema_csv_materializer.elisa"
integer_conversion="$repo_root/src/runtime/schema_integer_conversion.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$json_model" "$json_materializer" "$csv_materializer" "$integer_conversion" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'schema model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsSchemaCsv:' \
    'SCHEMA_CSV_MAX_PAYLOAD_BYTES' \
    'SCHEMA_CSV_MAX_BATCH_ROWS' \
    'SCHEMA_CSV_MAX_BATCH_VALUES' \
    'const enum SchemaCsvValueKind of u8:' \
    'struct SchemaCsvValue:' \
    'struct SchemaCsvRecord:' \
    'struct SchemaCsvRecordBatch:' \
    'error SchemaCsvMaterializeError:' \
    'def materialize_csv_schema_record(' \
    'def materialize_csv_schema_batch(' \
    'SchemaCsvValueKind.Integer' \
    'SchemaCsvValueKind.Decimal' \
    'schema_csv_prepare_projection(' \
    'schema_csv_materialize_row_with_projection(' \
    'parse_schema_integer(' \
    'parse_schema_decimal(' \
    'schema_csv_sort_name_indices(' \
    'schema_csv_sort_position_indices(' \
    'SchemaCsvDecodeState.Escaped'; do
    rg -Fq "$declaration" "$csv_materializer"
done

for declaration in \
    'JSON_MAX_OBJECT_LOOKUP_KEYS' \
    'def json_object_member_index(' \
    'def json_object_member_indices(' \
    'LookupLimitExceeded' \
    'json_object_member_index_validated'; do
    rg -Fq "$declaration" "$json_model"
done

for declaration in \
    'module EsSchemaJson:' \
    'using EsJson' \
    'using EsSchema' \
    'using EsSchemaNumeric' \
    'const enum SchemaJsonValueKind of u8:' \
    'SchemaJsonValueKind.Integer' \
    'SchemaJsonValueKind.Decimal' \
    'struct SchemaJsonOwnedNode:' \
    'struct SchemaJsonOwnedValueGraph:' \
    'struct SchemaJsonValue:' \
    'struct SchemaJsonRecord:' \
    'error SchemaJsonMaterializeError:' \
    'def materialize_json_schema_record(' \
    'def validate_schema_json_record(' \
    'schema_json_copy_nested_values(' \
    'schema_json_integer_value_valid(' \
    'json_object_member_indices(' \
    'SCHEMA_JSON_MAX_PAYLOAD_BYTES'; do
    rg -Fq "$declaration" "$json_materializer"
done

for declaration in \
    'module EsSchema:' \
    'using EsJson' \
    'using EsEncoding' \
    'SCHEMA_FORMAT_VERSION' \
    'const enum SchemaSource of u8:' \
    'const enum SchemaValueKind of u8:' \
    'const enum SchemaIntegerTarget of u8:' \
    'const enum SchemaDecimalTarget of u8:' \
    'struct SchemaIntegerValue:' \
    'struct SchemaDecimalValue:' \
    'const enum SchemaDecodeState of u8:' \
    'const enum SchemaDecodeEvent of u8:' \
    'struct SchemaField:' \
    'struct SchemaDescriptor:' \
    'struct SchemaBinding:' \
    'struct SchemaDecodeSession:' \
    'error SchemaContractError:' \
    'InvalidIntegerTarget' \
    'def validate_schema_descriptor(' \
    'def validate_schema_session(' \
    'def advance_schema_session(' \
    'try validate_schema_session(session)'; do
    rg -Fq "$declaration" "$model"
done

for declaration in \
    'module EsSchemaNumeric:' \
    'using EsRecordNumeric' \
    'using EsSchema' \
    'SCHEMA_INTEGER_MAX_BYTES' \
    'error SchemaIntegerError:' \
    'def parse_schema_integer(' \
    'def parse_schema_decimal(' \
    'SCHEMA_DECIMAL_MAX_BYTES' \
    'SCHEMA_DECIMAL_MAX_EXPONENT_DIGITS' \
    'allow_underscores: false' \
    'schema_integer_target_limit(' \
    'SchemaIntegerError.TargetOutOfRange'; do
    rg -Fq "$declaration" "$integer_conversion"
done

for boundary in \
    'BatchRowLimitExceeded' \
    'BatchValueLimitExceeded' \
    'row_count > available_rows - first_data_row' \
    'SCHEMA_CSV_MAX_BATCH_VALUES / row_count' \
    'record.payload_bytes > SCHEMA_CSV_MAX_PAYLOAD_BYTES - batch.payload_bytes' \
    'remaining_payload: usize = payload_limit - record.payload_bytes' \
    'field_payload_limit <- remaining_payload if remaining_payload < field_payload_limit' \
    'schema_csv_position_is_mapped'; do
    rg -Fq "$boundary" "$csv_materializer"
done

for boundary in \
    'field.integer_target != SchemaIntegerTarget.None and schema.source == SchemaSource.Json and field.kind != SchemaValueKind.Number' \
    'field.integer_target != SchemaIntegerTarget.None and schema.source != SchemaSource.Json and field.kind != SchemaValueKind.Text' \
    'field.decimal_target != SchemaDecimalTarget.None and schema.source == SchemaSource.Json and field.kind != SchemaValueKind.Number' \
    'field.decimal_target != SchemaDecimalTarget.None and schema.source != SchemaSource.Json and field.kind != SchemaValueKind.Text' \
    'field.integer_target != SchemaIntegerTarget.None and field.decimal_target != SchemaDecimalTarget.None'; do
    rg -Fq "$boundary" "$model"
done

for boundary in \
    'DuplicateField' \
    'DuplicateSourceName' \
    'schema_effective_source_name(field)' \
    'schema_sort_field_indices(' \
    'utf8_complete(cursor)' \
    'ValueKindMismatch' \
    'raise SchemaContractError.InvalidValueKind if not schema_json_node_kind_valid(node.kind)' \
    'schema_json_node_kind_valid' \
    'session.state == SchemaDecodeState.Ready' \
    'SchemaDecodeState.Complete' \
    'RequiredFieldMissing' \
    'BindingLimitExceeded' \
    'BindNotReady' \
    'CompleteNotReady'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/schema_model.elisa"' "$ir"
rg -Fq 'include "../runtime/schema_integer_conversion.elisa"' "$ir"
rg -Fq 'include "../runtime/schema_json_materializer.elisa"' "$ir"
rg -Fq 'include "../runtime/schema_csv_materializer.elisa"' "$ir"
for fixture_pattern in \
    'typed_schema_binding_contract_checks_json_kinds_and_required_fields' \
    'typed_json_schema_materializer_owns_scalars_and_preserves_schema_order' \
    'typed_json_schema_materializer_owns_nested_values_iteratively_and_preserves_order' \
    'typed_schema_json_integer_targets_convert_exactly_without_float_rounding' \
    'typed_schema_json_decimal_target_preserves_exact_scale_and_negative_zero' \
    'typed_csv_schema_integer_targets_decode_signed_and_unsigned_fields' \
    'typed_csv_schema_decimal_target_preserves_exact_scale_and_batch_payload' \
    'typed_csv_schema_materializer_binds_header_aliases_and_optional_fields' \
    'typed_csv_schema_batch_projects_exact_ranges_with_shared_mapping' \
    'typed_csv_schema_materializer_distinguishes_empty_from_missing_and_maps_positions' \
    'typed_csv_schema_materializer_unescapes_quotes_and_rejects_duplicate_header_names' \
    'SchemaCsvValueKind.Missing' \
    'SchemaCsvMaterializeError.DuplicateHeader' \
    'SchemaDecodeEvent.Bind' \
    'SchemaContractError.ValueKindMismatch' \
    'SchemaJsonMaterializeError.UnsupportedValueKind' \
    'SchemaJsonValueKind.Missing' \
    'forged_ready' \
    'forged_integer_rejected' \
    'forged_complete'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsSchema`' "$docs"
rg -Fq '`EsSchemaCsv` materializes completed CSV/TSV records' "$docs"
rg -Fq 'header/positional projection once per call' "$docs"
rg -Fq 'Latest P08 typed JSON schema follow-up' "$plan"

printf 'schema model audit: owned nested JSON values, typed schema binding, and bounded CSV row batches are present\n'
