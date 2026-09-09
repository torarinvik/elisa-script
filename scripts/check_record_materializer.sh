#!/usr/bin/env bash

# Compiler-free audit for bounded Perl/AWK-style record materialization.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_materializer_model.elisa"
record_model="$repo_root/src/runtime/record_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$record_model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'record materializer audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q '^module EsRecordMaterialize:' "$model"
rg -q 'include "\.\./runtime/record_materializer_model\.elisa"' "$ir"
rg -q '^module EsRecord:' "$record_model"

for declaration in \
    'const enum RecordMaterializerState of u8' \
    'const enum RecordMaterializerEvent of u8' \
    'struct MaterializedRecord:' \
    'struct RecordMaterializer:' \
    'error RecordMaterializerError:' \
    'def validate_record_materializer\(' \
    'def advance_record_materializer\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'RECORD_MATERIALIZER_MAX_RECORDS' \
    'RECORD_MATERIALIZER_MAX_FIELDS' \
    'RECORD_MATERIALIZER_MAX_TEXT_BYTES' \
    'record_materializer_policy_valid' \
    'record_materializer_record_valid' \
    'record_materializer_field_valid' \
    'record_materializer_idle_record_valid' \
    'RecordMaterializerError.FieldOrderInvalid' \
    'RecordMaterializerError.AccountingInvalid' \
    'RecordMaterializerError.TextLimitExceeded' \
    'RecordMaterializerState.Planned' \
    'RecordMaterializerState.Collecting' \
    'RecordMaterializerState.Sealed' \
    'RecordMaterializerEvent.BeginRecord' \
    'RecordMaterializerEvent.EndRecord' \
    'RecordMaterializerEvent.Seal' \
    'RecordMaterializerEvent.Cancel' \
    'materializer.fields.truncate'; do
    rg -q "$boundary" "$model"
done

rg -q 'materializer.current_field_start > materializer.fields.count' "$model"
rg -q 'materializer.current_field_count > materializer.fields.count - materializer.current_field_start' "$model"
rg -q 'item.field_start > materializer.fields.count' "$model"
rg -q 'item.field_count > materializer.fields.count - item.field_start' "$model"

rg -Fq 'current_record <- Record{source: ""}' "$model"
rg -Fq 'not materializer.record_open and (materializer.current_field_start != 0 or materializer.current_field_count != 0)' "$model"
rg -q -U 'elif event == RecordMaterializerEvent.EndRecord:\n                raise RecordMaterializerError.InvalidState if materializer.state != RecordMaterializerState.Collecting\n                raise RecordMaterializerError.RecordNotOpen if not materializer.record_open\n                raise RecordMaterializerError.RecordLimitExceeded if materializer.records.count >= RECORD_MATERIALIZER_MAX_RECORDS' "$model"

for fixture_pattern in \
    'using EsRecordMaterialize' \
    'typed_record_materializer_contract_is_ordered_and_bounded' \
    'RecordMaterializerError.FieldOrderInvalid' \
    'RecordMaterializerError.AccountingInvalid' \
    'forged_planned' \
    'forged_idle' \
    'forged_cursor' \
    'RecordMaterializerState.Sealed' \
    'RecordMaterializerState.Cancelled'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordMaterialize::RecordMaterializer' "$docs"
rg -q 'ES-SCRIPT-023' "$ledger"
rg -q 'P11 materialization follow-up' "$plan"

printf 'record materializer audit: bounded ordered lifecycle and ownership checks are present\n'
