#!/usr/bin/env bash

# Compiler-free audit for bounded deterministic record sorting.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_sort_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'record sort audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordSort:' "$model"
rg -q 'include "\.\./runtime/record_sort_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordSortKeyKind of u8' \
    'const enum RecordSortDirection of u8' \
    'const enum RecordSortOrder of u8' \
    'struct RecordSortPolicy:' \
    'struct RecordSortEntry:' \
    'struct RecordSortSession:' \
    'error RecordSortError:' \
    'def validate_record_sort_session\(' \
    'def compare_record_sort_entries\(' \
    'def advance_record_sort\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'RECORD_SORT_MAX_KEYS' \
    'RECORD_SORT_MAX_RECORDS' \
    'RECORD_SORT_MAX_TEXT_BYTES' \
    'record_sort_policy_valid' \
    'record_sort_entry_valid' \
    'RecordSortError.KeyOrderInvalid' \
    'RecordSortError.OrdinalInvalid' \
    'RecordSortError.UniqueViolation' \
    'not key.present and (key.text != "" or key.integer != 0)' \
    'key.kind == RecordSortKeyKind.Integer and key.text != ""' \
    'session.state == RecordSortState.Planned and' \
    'record_sort_keys_equal' \
    'RecordSortError.TextLimitExceeded' \
    'RecordSortDirection.Descending' \
    'RecordSortState.Sealed'; do
    rg -Fq "$boundary" "$model"
done

for fixture_pattern in \
    'using EsRecordSort' \
    'typed_record_sort_contract_is_bounded_stable_and_typed' \
    'RecordSortKeyKind.Integer' \
    'RecordSortDirection.Descending' \
    'RecordSortError.PolicyInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordSort::RecordSortSession' "$docs"
rg -q 'ES-SCRIPT-024' "$ledger"
rg -q 'P11 sort follow-up' "$plan"

printf 'record sort audit: bounded typed keys, stable order, and lifecycle checks are present\n'
