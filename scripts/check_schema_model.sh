#!/usr/bin/env bash

# Compiler-free audit for typed structured-data schema binding.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/schema_model.elisa"
json_model="$repo_root/src/runtime/json_model.elisa"
json_materializer="$repo_root/src/runtime/schema_json_materializer.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$json_model" "$json_materializer" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'schema model audit: missing %s\n' "$required_file" >&2; exit 1; }
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
    'const enum SchemaJsonScalarKind of u8:' \
    'struct SchemaJsonValue:' \
    'struct SchemaJsonRecord:' \
    'error SchemaJsonMaterializeError:' \
    'def materialize_json_schema_record(' \
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
    'const enum SchemaDecodeState of u8:' \
    'const enum SchemaDecodeEvent of u8:' \
    'struct SchemaField:' \
    'struct SchemaDescriptor:' \
    'struct SchemaBinding:' \
    'struct SchemaDecodeSession:' \
    'error SchemaContractError:' \
    'def validate_schema_descriptor(' \
    'def validate_schema_session(' \
    'def advance_schema_session(' \
    'try validate_schema_session(session)'; do
    rg -Fq "$declaration" "$model"
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
rg -Fq 'include "../runtime/schema_json_materializer.elisa"' "$ir"
for fixture_pattern in \
    'typed_schema_binding_contract_checks_json_kinds_and_required_fields' \
    'typed_json_schema_materializer_owns_scalars_and_preserves_schema_order' \
    'SchemaDecodeEvent.Bind' \
    'SchemaContractError.ValueKindMismatch' \
    'SchemaJsonMaterializeError.UnsupportedValueKind' \
    'SchemaJsonScalarKind.Missing' \
    'forged_ready' \
    'forged_complete'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsSchema`' "$docs"
rg -Fq 'Latest P08 typed JSON schema follow-up' "$plan"

printf 'schema model audit: typed JSON binding and owned scalar materialization are present\n'
