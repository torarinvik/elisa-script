#!/usr/bin/env bash

# Compiler-free audit for typed structured-data schema binding.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/schema_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'schema model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsSchema:' \
    'using EsJson' \
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
    'def advance_schema_session('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'DuplicateField' \
    'DuplicateSourceName' \
    'ValueKindMismatch' \
    'RequiredFieldMissing' \
    'BindingLimitExceeded' \
    'BindNotReady' \
    'CompleteNotReady'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/schema_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_schema_binding_contract_checks_json_kinds_and_required_fields' \
    'SchemaDecodeEvent.Bind' \
    'SchemaContractError.ValueKindMismatch'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsSchema`' "$docs"
rg -Fq 'Latest P08 schema-binding follow-up' "$plan"

printf 'schema model audit: typed field declarations and fail-closed JSON kind binding are present\n'
