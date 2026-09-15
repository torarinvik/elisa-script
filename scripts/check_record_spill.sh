#!/usr/bin/env bash

# Compiler-free audit for bounded external-sort spill/merge state.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_spill_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'record spill audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordSpill:' "$model"
rg -q 'include "\.\./runtime/record_spill_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordSpillState of u8' \
    'const enum RecordSpillEvent of u8' \
    'struct RecordSpillPolicy:' \
    'struct RecordSpillRun:' \
    'struct RecordSpillSession:' \
    'error RecordSpillError:' \
    'def validate_record_spill\(' \
    'def advance_record_spill\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'RECORD_SPILL_MAX_RUNS' \
    'RECORD_SPILL_MAX_RECORDS_PER_RUN' \
    'RECORD_SPILL_MAX_TOTAL_RECORDS' \
    'RECORD_SPILL_MAX_RUN_BYTES' \
    'RECORD_SPILL_MAX_TOTAL_BYTES' \
    'record_spill_bounded_add' \
    'has_active_run' \
    'RecordSpillState.Planned' \
    'RecordSpillState.Ready' \
    'RecordSpillState.Merging' \
    'RecordSpillState.Sealed' \
    'session.merged_runs != session.runs.count' \
    'session.state == RecordSpillState.Merging or session.state == RecordSpillState.Sealed' \
    'RecordSpillEvent.SealRun' \
    'session.state <- RecordSpillState.Spilling' \
    'RecordSpillEvent.BeginMerge' \
    'RecordSpillEvent.MergeRun' \
    'RecordSpillError.MergeOrderInvalid' \
    'RecordSpillError.RunNotSealed' \
    'session.state != RecordSpillState.Ready' \
    'RecordSpillError.DestinationCollision' \
    'not session.has_active_run and' \
    'RecordSpillState.Sealed'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsRecordSpill' \
    'typed_record_spill_contract_seals_runs_before_ordered_merge' \
    'RecordSpillEvent.StartRun' \
    'RecordSpillEvent.SealRun' \
    'RecordSpillEvent.MergeRun' \
    'RecordSpillError.MergeOrderInvalid' \
    'RecordSpillError.AccountingInvalid' \
    'forged_empty_merging' \
    'forged_empty_sealed' \
    'forged_state'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordSpill::RecordSpillSession' "$docs"
rg -q 'ES-SCRIPT-034' "$ledger"
rg -q 'P11 external-spill follow-up' "$plan"

printf 'record spill audit: bounded run staging, sealing, ordered merge, and commit are present\n'
