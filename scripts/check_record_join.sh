#!/usr/bin/env bash

# Compiler-free audit for deterministic bounded keyed joins.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_join_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'record join audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordJoin:' "$model"
rg -q 'include "\.\./runtime/record_join_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordJoinState of u8' \
    'const enum RecordJoinEvent of u8' \
    'const enum RecordJoinSide of u8' \
    'const enum RecordJoinKind of u8' \
    'struct RecordJoinPolicy:' \
    'struct RecordJoinRow:' \
    'struct RecordJoinSession:' \
    'error RecordJoinError:' \
    'def validate_record_join\(' \
    'def record_join_pair_count\(' \
    'def advance_record_join\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'RECORD_JOIN_MAX_ROWS' \
    'RECORD_JOIN_MAX_PAIRS' \
    'RECORD_JOIN_MAX_KEY_BYTES' \
    'RECORD_JOIN_MAX_VALUE_BYTES' \
    'record_join_bounded_add' \
    'record_join_pair_add' \
    'session.left_count > session.rows.count or session.right_count > session.rows.count' \
    'RecordJoinKind.Full' \
    'RecordJoinError.EmptyKey' \
    'RecordJoinError.PairLimitExceeded' \
    'RecordJoinError.AccountingInvalid' \
    'session.state == RecordJoinState.Planned and' \
    'RecordJoinEvent.Add' \
    'RecordJoinState.Sealed'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsRecordJoin' \
    'typed_record_join_contract_counts_duplicate_and_outer_pairs' \
    'RecordJoinSide.Left' \
    'RecordJoinSide.Right' \
    'record_join_pair_count' \
    'forged_count_bound' \
    'RecordJoinError.EmptyKey'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordJoin::RecordJoinSession' "$docs"
rg -q 'ES-SCRIPT-032' "$ledger"
rg -q 'P11 keyed-join follow-up' "$plan"

printf 'record join audit: bounded duplicate-key matching and explicit outer pairs are present\n'
