#!/usr/bin/env bash

# Compiler-free audit for typed structured-data schema binding.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/schema_model.elisa"
json_model="$repo_root/src/runtime/json_model.elisa"
json_materializer="$repo_root/src/runtime/schema_json_materializer.elisa"
csv_materializer="$repo_root/src/runtime/schema_csv_materializer.elisa"
toml_materializer="$repo_root/src/runtime/schema_toml_materializer.elisa"
integer_conversion="$repo_root/src/runtime/schema_integer_conversion.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
toml_fixture="$repo_root/test/runtime/schema_toml_materializer_test.elisa"
docs="$repo_root/docs/ir.md"

for required_file in "$model" "$json_model" "$json_materializer" "$csv_materializer" "$toml_materializer" "$integer_conversion" "$ir" "$fixture" "$toml_fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'schema model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsSchemaToml:' \
    'using EsConfigToml' \
    'using EsSchema' \
    'using EsSchemaNumeric' \
    'SCHEMA_TOML_MAX_VALUES' \
    'SCHEMA_TOML_MAX_TYPES' \
    'SCHEMA_TOML_MAX_NESTED_FIELDS' \
    'const enum SchemaTomlValueKind of u8:' \
    'struct SchemaTomlValue:' \
    'struct SchemaTomlRecord:' \
    'error SchemaTomlMaterializeError:' \
    'def materialize_toml_schema_record(' \
    'def materialize_toml_schema_table(' \
    'schema_toml_key_is_direct_child(' \
    'schema_toml_integer_decimal_bytes(' \
    'schema_toml_separators_valid(' \
    'schema_toml_node_type_valid(' \
    'validate_toml_value_graph(' \
    'SchemaTomlValueKind.Missing' \
    'SchemaTomlValueKind.Array' \
    'SchemaTomlValueKind.Object' \
    'SchemaTomlMaterializeError.DuplicateField' \
    'SchemaTomlMaterializeError.UnknownField'; do
    rg -Fq "$declaration" "$toml_materializer"
done

for fixture_pattern in \
    'toml_schema_binds_typed_config_and_text_overrides' \
    'toml_schema_rejects_unknown_and_missing_required_fields' \
    'toml_schema_rejects_malformed_numeric_override_separators' \
    'SchemaTypeNode{kind: SchemaValueKind.Array, array_item_type_index: 0}' \
    'SchemaTypeNode{kind: SchemaValueKind.Object, object_field_start: 0, object_field_count: 2}' \
    'toml_schema_binds_one_table_and_ignores_siblings_and_descendants' \
    'source_name: "workers"' \
    'SchemaTomlValueKind.Integer' \
    'SchemaTomlValueKind.Decimal' \
    'SchemaTomlValueKind.Array' \
    'SchemaTomlValueKind.Object' \
    'SchemaTomlMaterializeError.UnknownField' \
    'SchemaTomlMaterializeError.InvalidNumber' \
    'wrong_item_rejected' \
    'duplicate_rejected' \
    'missing_inline_rejected' \
    'SchemaContractError.RequiredFieldMissing'; do
    rg -Fq "$fixture_pattern" "$toml_fixture"
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
    'SchemaJsonNumberRepresentation' \
    'error SchemaJsonMaterializeError:' \
    'def materialize_json_schema_record(' \
    'def validate_schema_json_record(' \
    'def validate_schema_json_record_against(' \
    'schema_json_copy_nested_values(' \
    'schema_json_required_field_counts(' \
    'schema_json_sort_owned_member_indices(' \
    'schema_json_record_matches_validated_schema(' \
    'SchemaJsonMaterializeError.DuplicateField' \
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
    'struct SchemaTypeNode:' \
    'struct SchemaNestedField:' \
    'SCHEMA_MAX_TYPES' \
    'SCHEMA_MAX_NESTED_FIELDS' \
    'SCHEMA_MAX_TOTAL_NAME_BYTES' \
    'const enum SchemaDecodeState of u8:' \
    'const enum SchemaDecodeEvent of u8:' \
    'struct SchemaField:' \
    'struct SchemaDescriptor:' \
    'struct SchemaBinding:' \
    'struct SchemaDecodeSession:' \
    'error SchemaContractError:' \
    'InvalidIntegerTarget' \
    'InvalidNestedFieldOrder' \
    'schema_type_graph_fully_reachable(' \
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
    'SCHEMA_DECIMAL_MAX_FORMAT_BYTES' \
    'const enum SchemaDecimalOrdering of u8:' \
    'const enum SchemaDecimalRounding of u8:' \
    'allow_underscores: false' \
    'schema_integer_target_limit(' \
    'def compare_schema_decimal(' \
    'def round_schema_decimal(' \
    'def format_schema_decimal(' \
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
    'numeric_source: bool = schema.source == SchemaSource.Json or schema.source == SchemaSource.Toml' \
    'schema.source != SchemaSource.Json and schema.source != SchemaSource.Toml and (schema.types.count != 0 or schema.nested_fields.count != 0)' \
    'field.integer_target != SchemaIntegerTarget.None and numeric_source and field.kind != SchemaValueKind.Number' \
    'field.integer_target != SchemaIntegerTarget.None and not numeric_source and field.kind != SchemaValueKind.Text' \
    'field.decimal_target != SchemaDecimalTarget.None and numeric_source and field.kind != SchemaValueKind.Number' \
    'field.decimal_target != SchemaDecimalTarget.None and not numeric_source and field.kind != SchemaValueKind.Text' \
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
rg -Fq 'include "../runtime/schema_toml_materializer.elisa"' "$ir"
for fixture_pattern in \
    'typed_schema_binding_contract_checks_json_kinds_and_required_fields' \
    'typed_json_schema_materializer_owns_scalars_and_preserves_schema_order' \
    'typed_json_schema_materializer_owns_nested_values_iteratively_and_preserves_order' \
    'typed_json_schema_materializer_checks_recursive_nested_types_and_exact_numbers' \
    'forged_unknown_rejected' \
    'forged_duplicate_rejected' \
    'typed_schema_json_integer_targets_convert_exactly_without_float_rounding' \
    'typed_schema_json_decimal_target_preserves_exact_scale_and_negative_zero' \
    'exact_schema_decimal_comparison_uses_numeric_value_not_representation' \
    'exact_schema_decimal_rounding_and_fixed_formatting_obey_explicit_policies' \
    'SchemaDecimalRounding.HalfToEven' \
    'SchemaDecimalRounding.HalfAwayFromZero' \
    'carry_result.coefficient_digits.count == SCHEMA_DECIMAL_MAX_DIGITS' \
    'maximum_width_text.count == SCHEMA_DECIMAL_MAX_FORMAT_BYTES' \
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
rg -Fq '`EsSchemaToml` binds resolved TOML configuration' "$docs"
rg -Fq 'Schema type graphs validate recursive array items' "$docs"
rg -Fq '`validate_schema_json_record_against` rechecks those annotations' "$docs"
rg -Fq 'header/positional projection once per call' "$docs"

printf 'schema model audit: recursively typed JSON values, bounded TOML schema validation, and CSV row batches are present\n'
