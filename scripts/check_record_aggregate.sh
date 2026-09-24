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
runtime_fixture="$repo_root/test/runtime/record_aggregate_model_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
candidate="$repo_root/scripts/check_record_aggregate.elisascript"

for required_file in "$model" "$ir" "$fixture_file" "$runtime_fixture" "$docs" "$ledger" "$candidate"; do
    [[ -f "$required_file" && -r "$required_file" ]] || { printf 'record aggregate audit: missing %s\n' "$required_file" >&2; exit 1; }
done

max_source_bytes=16777216
max_total_source_bytes=4194304
total_source_bytes=0
for required_file in "$model" "$ir" "$fixture_file" "$runtime_fixture" "$docs" "$ledger"; do
    source_bytes="$(LC_ALL=C wc -c < "$required_file")"
    if (( source_bytes > max_source_bytes || total_source_bytes > max_total_source_bytes - source_bytes )); then
        printf 'record aggregate audit: source exceeds audit limit: %s\n' "$required_file" >&2
        exit 2
    fi
    total_source_bytes=$((total_source_bytes + source_bytes))
done

rg -Fq 'module EsRecordAggregateAudit:' "$candidate"
rg -Fq 'def read_source(' "$candidate"
rg -Fq 'current_size: usize = try file_size(input_path)' "$candidate"
pre_read_size_line="$(rg -n -m1 -F 'current_size: usize = try file_size(input_path)' "$candidate" | cut -d: -f1)"
read_text_line="$(rg -n -m1 -F 'source: sview = try read_text(input_path)' "$candidate" | cut -d: -f1)"
[[ -n "$pre_read_size_line" && -n "$read_text_line" ]]
(( pre_read_size_line < read_text_line ))
rg -Fq 'def run(repository_root: sview)' "$candidate"
rg -Fq 'def run_default()' "$candidate"
rg -Fq 'Script::source_path()' "$candidate"
rg -Fq 'candidate_path: Path = try path_absolute(Script::source_path())' "$candidate"
rg -Fq 'if not is_file(candidate_path) or not is_readable(candidate_path)' "$candidate"
rg -Fq 'script_directory.parent()' "$candidate"
rg -Fq 'if not is_directory(root_absolute)' "$candidate"
rg -Fq "Match the shell reference's path/readability preflight" "$candidate"
rg -Fq 'not is_readable(input_path)' "$candidate"
rg -Fq 'source_sizes.push(source_size)' "$candidate"
rg -Fq 'catch read_source(input_path, source_sizes[source_index])' "$candidate"
rg -Fq 'Limits::TOTAL_SOURCE_BYTES - total_bytes' "$candidate"
rg -Fq 'usage: record aggregate audit [repository-root]' "$candidate"
launcher_parity="$repo_root/test/script_parity/record_aggregate_launcher_test.elisascript"
rg -Fq 'def script_relative_default_matches(' "$launcher_parity"
rg -Fq 'working_directory: "/"' "$launcher_parity"
rg -Fq 'use_default_root: true' "$launcher_parity"
rg -Fq 'missing_first_precedes_later' "$launcher_parity"
rg -Fq 'missing_precedes_overflow' "$launcher_parity"
rg -Fq 'unreadable_precedes_overflow' "$launcher_parity"
rg -Fq 'original_docs_permissions <- mode & 4095u64' "$launcher_parity"
rg -Fq 'restored_docs_mode & 4095u64' "$launcher_parity"
rg -Fq 'REFERENCE_BYTES: usize = 65536' "$launcher_parity"
rg -Fq 'reference_script_in_root: Path = path_join(path(test_case.repository_root), Commands::REFERENCE_SCRIPT)' "$launcher_parity"
rg -Fq 'write_fixture_text(path_join(root, Commands::REFERENCE_SCRIPT), reference)' "$launcher_parity"
rg -Fq 'candidate_script_in_root: Path = path_join(path(test_case.repository_root), Commands::CANDIDATE_SCRIPT)' "$launcher_parity"
rg -Fq 'padded_docs.push(195u8)' "$launcher_parity"
rg -Fq 'padded_docs.push(169u8)' "$launcher_parity"
rg -Fq 'file_root_case' "$launcher_parity"
size_admission_line="$(rg -n -m1 -F 'source_sizes.push(source_size)' "$candidate" | cut -d: -f1)"
source_read_line="$(rg -n -m1 -F 'catch read_source(input_path, source_sizes[source_index])' "$candidate" | cut -d: -f1)"
[[ -n "$size_admission_line" && -n "$source_read_line" ]]
(( size_admission_line < source_read_line ))
candidate_preflight_line="$(rg -n -m1 -F 'if not is_file(candidate_path) or not is_readable(candidate_path)' "$candidate" | cut -d: -f1)"
source_admission_line="$(rg -n -m1 -F 'for relative in relative_paths |relative_paths, root_absolute, root_text, source_sizes, total_bytes|' "$candidate" | cut -d: -f1)"
[[ -n "$candidate_preflight_line" && -n "$source_admission_line" ]]
(( candidate_preflight_line < source_admission_line ))

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
    'const module Limits:' \
    'GROUPS: usize = 1048576' \
    'EVENTS: usize = 1048576' \
    'KEY_BYTES: usize = 268435456' \
    'SUM: u64 = 67108864' \
    'INDEX_SLOTS: usize = 2097152' \
    'sum: i64 = 0' \
    '-> i64 error\[RecordAggregateError\]' \
    '0 - session.policy.max_sum.i64()' \
    'value > sum_limit or value < 0 - sum_limit' \
    'value < 0 and session.groups\[index\].sum < 0 - sum_limit - value' \
    'record_aggregate_key_hash' \
    'record_aggregate_index_find' \
    'record_aggregate_index_place' \
    'record_aggregate_ensure_index_capacity' \
    'validate_record_aggregate_header' \
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

rg -q 'indexed_groups != session.groups.count' "$model"
rg -q 'record_aggregate_index_find\(session.groups, session.index_slots, group.key\)' "$model"
rg -q 'try validate_record_aggregate_header\(session\)' "$model"
rg -q 'try record_aggregate_ensure_index_capacity\(session\)' "$model"
! rg -q 'record_aggregate_index\(session, key\)' "$model"

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
rg -q 'record_aggregate_hash_index_preserves_order_and_rejects_damage' "$runtime_fixture"
rg -q 'signed_aggregate' "$runtime_fixture"
rg -q 'record_aggregate_group_sum\(signed_aggregate, "alpha"\) == -2' "$runtime_fixture"
rg -q 'negative_sum_rejected' "$runtime_fixture"
rg -q 'damaged.index_slots\[index\] <- 0' "$runtime_fixture"
rg -q 'RecordAggregateError.AccountingInvalid' "$runtime_fixture"
rg -q 'RecordAggregateError.SumLimitExceeded' "$runtime_fixture"

printf 'record aggregate audit: bounded insertion-ordered groups and sealed lookup are present\n'
