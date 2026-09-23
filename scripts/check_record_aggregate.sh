#!/usr/bin/env bash

# Compiler-free audit for bounded associative record aggregation.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if (($# > 1)); then
    printf 'usage: record aggregate audit [repository-root]\n' >&2
    exit 2
fi
repo_root_operand="$script_dir/.."
if (($# == 1)); then
    repo_root_operand="$1"
fi
repo_root="$(CDPATH= cd -- "$repo_root_operand" 2>/dev/null && pwd 2>/dev/null)" || {
    printf 'record aggregate audit: missing repository root\n' >&2
    exit 1
}
model="$repo_root/src/runtime/record_aggregate_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
candidate="$repo_root/scripts/check_record_aggregate.elisascript"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$candidate"; do
    [[ -f "$required_file" && -r "$required_file" ]] || { printf 'record aggregate audit: missing %s\n' "$required_file" >&2; exit 1; }
done

max_source_bytes=16777216
max_total_source_bytes=4194304
total_source_bytes=0
for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger"; do
    source_bytes="$(LC_ALL=C wc -c < "$required_file")"
    if (( source_bytes > max_source_bytes || total_source_bytes > max_total_source_bytes - source_bytes )); then
        printf 'record aggregate audit: source exceeds audit limit: %s\n' "$required_file" >&2
        exit 2
    fi
    total_source_bytes=$((total_source_bytes + source_bytes))
done

rg -Fq 'module EsRecordAggregateAudit:' "$candidate"
rg -Fq 'def read_source(' "$candidate"
rg -Fq 'def run(repository_root: sview)' "$candidate"
rg -Fq 'def run_default()' "$candidate"
rg -Fq 'Script::source_path()' "$candidate"
rg -Fq 'script_directory.parent()' "$candidate"
rg -Fq 'Limits::TOTAL_SOURCE_BYTES - total_bytes' "$candidate"
rg -Fq 'usage: record aggregate audit [repository-root]' "$candidate"
launcher_parity="$repo_root/test/script_parity/record_aggregate_launcher_test.elisascript"
rg -Fq 'def script_relative_default_matches(' "$launcher_parity"
rg -Fq 'working_directory: "/"' "$launcher_parity"
rg -Fq 'use_default_root: true' "$launcher_parity"

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
    'sview_len\(key\) <= policy.max_key_bytes' \
    'RecordAggregateError.GroupLimitExceeded' \
    'RecordAggregateError.EventLimitExceeded' \
    'RecordAggregateError.KeyBytesLimitExceeded' \
    'RecordAggregateError.AccountingInvalid' \
    'session.state == RecordAggregateState.Planned and' \
    'accounted_events' \
    'previous_first_ordinal' \
    'group.first_ordinal <= previous_first_ordinal' \
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
    'max_key_bytes: 5' \
    '"12345"' \
    'forged_aggregate_order' \
    'RecordAggregateError.GroupIndexInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordAggregate::RecordAggregateSession' "$docs"
rg -q 'ES-SCRIPT-027' "$ledger"

printf 'record aggregate audit: bounded insertion-ordered groups and sealed lookup are present\n'
