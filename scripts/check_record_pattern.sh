#!/usr/bin/env bash

# Compiler-free audit for bounded pattern/action and inclusive-range records.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_pattern_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'record pattern audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordPattern:' "$model"
rg -q 'include "\.\./runtime/record_pattern_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordPatternState of u8' \
    'const enum RecordPatternPredicateKind of u8' \
    'const enum RecordPatternAction of u8' \
    'struct RecordPatternClause:' \
    'record_policy: RecordStreamPolicy' \
    'struct RecordPatternObservation:' \
    'struct RecordPatternDecision:' \
    'struct RecordPatternSession:' \
    'error RecordPatternError:' \
    'def validate_record_pattern_session\(' \
    'def advance_record_pattern\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'Limits::CLAUSES' \
    'Limits::RECORDS' \
    'Limits::MATCH_WORK' \
    'max_match_work' \
    'record_pattern_charge_match_work' \
    'record_pattern_text_equal' \
    'record_pattern_text_contains' \
    'RecordPatternError.MatchWorkLimitExceeded' \
    'MatchWorkAccountingInvalid' \
    'derived_match_work' \
    'decision.match_work <= derived_match_work' \
    'match_work: record_match_work' \
    'while offset < sview_len(needle) and matched' \
    'RecordPatternPredicateKind.External' \
    'RecordPatternEvent.Record' \
    'RecordPatternError.ObservationShapeInvalid' \
    'RecordPatternError.AccountingInvalid' \
    'clause_state == RecordPatternClauseState.Active and not session.clauses[index].has_end' \
    'decision.record_number <= session.decisions[index - 1].record_number' \
    'RecordPatternError.EndNotReady' \
    'record_pattern_predicate_valid(clause.end, policy)' \
    'session.decisions.count != session.processed_records' \
    'RecordPatternClauseState.Active'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsRecordPattern' \
    'typed_record_pattern_contract_selects_inclusive_ranges' \
    'RecordPatternPredicateKind.RecordNumberEquals' \
    'RecordPatternError.ObservationShapeInvalid' \
    'RecordPatternError.AccountingInvalid' \
    'session.policy.record_policy' \
    'preserved_policy' \
    'preserved_observation' \
    'rejected_separator_session' \
    'forged_accounting' \
    'forged_record_order' \
    'duplicate_record_order' \
    'hidden_end_payload' \
    'active_without_end_rejected' \
    'RecordPatternError.InvalidClause' \
    'record_pattern_selected' \
    'boundary_pattern_policy' \
    'bounded_match_session' \
    'match_work_rejected' \
    'forged_match_work' \
    'missing_decision_work' \
    'RecordPatternError.MatchWorkAccountingInvalid' \
    'session.match_work == 4' \
    'equal_session.match_work == 5' \
    'range_work_session.match_work == 4' \
    'max_text_bytes: 4'; do
    rg -q "$fixture_pattern" "$fixture_file"
done
rg -Fq 'record_selected: mutable bool = false' "$model"
rg -Fq 'multi_clauses' "$fixture_file"
rg -Fq 'sview_len(value) <= policy.max_text_bytes' "$model"

rg -q 'EsRecordPattern::RecordPatternSession' "$docs"
rg -q 'ES-SCRIPT-039' "$ledger"

printf 'record pattern audit: bounded pattern/action and inclusive-range selection are present\n'
