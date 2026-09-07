#!/usr/bin/env bash

# Compiler-free audit for bounded associative record aggregation.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_aggregate_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'record aggregate audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordAggregate:' "$model"
rg -q 'include "\.\./runtime/record_aggregate_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordAggregateState of u8' \
    'const enum RecordAggregateEvent of u8' \
    'struct RecordAggregatePolicy:' \
    'struct RecordAggregateGroup:' \
    'struct RecordAggregateSession:' \
    'error RecordAggregateError:' \
    'def validate_record_aggregate\(' \
    'def record_aggregate_group_count\(' \
    'def record_aggregate_group_sum\(' \
    'def advance_record_aggregate\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'RECORD_AGGREGATE_MAX_GROUPS' \
    'RECORD_AGGREGATE_MAX_EVENTS' \
    'RECORD_AGGREGATE_MAX_KEY_BYTES' \
    'RECORD_AGGREGATE_MAX_SUM' \
    'record_aggregate_key_valid' \
    'RecordAggregateError.GroupLimitExceeded' \
    'RecordAggregateError.EventLimitExceeded' \
    'RecordAggregateError.KeyBytesLimitExceeded' \
    'RecordAggregateError.GroupIndexInvalid' \
    'RecordAggregateEvent.Add' \
    'RecordAggregateEvent.AddValue' \
    'SumLimitExceeded' \
    'RecordAggregateEvent.Seal'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsRecordAggregate' \
    'typed_record_aggregate_contract_is_bounded_and_insertion_ordered' \
    'RecordAggregateEvent.Add' \
    'record_aggregate_group_count' \
    'RecordAggregateError.GroupIndexInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordAggregate::RecordAggregateSession' "$docs"
rg -q 'ES-SCRIPT-027' "$ledger"
rg -q 'P11 aggregation follow-up' "$plan"

printf 'record aggregate audit: bounded insertion-ordered groups and sealed lookup are present\n'
