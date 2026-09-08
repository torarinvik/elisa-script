#!/usr/bin/env bash

# Compiler-free audit for bounded rolling record windows.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_window_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'record window audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordWindow:' "$model"
rg -q 'include "\.\./runtime/record_window_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordWindowState of u8' \
    'const enum RecordWindowEvent of u8' \
    'struct RecordWindowPolicy:' \
    'struct RecordWindowSession:' \
    'error RecordWindowError:' \
    'def validate_record_window\(' \
    'def record_window_count\(' \
    'def record_window_sum\(' \
    'def advance_record_window\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'RECORD_WINDOW_MAX_WIDTH' \
    'RECORD_WINDOW_MAX_EVENTS' \
    'RECORD_WINDOW_MAX_SUM' \
    'active_start' \
    'record_window_sum_valid' \
    'for value in session.values' \
    'session.state == RecordWindowState.Planned' \
    'session.values.count == 0' \
    'RecordWindowError.EventLimitExceeded' \
    'RecordWindowError.WidthExceeded' \
    'RecordWindowError.SumLimitExceeded' \
    'RecordWindowEvent.Push' \
    'RecordWindowState.Sealed'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsRecordWindow' \
    'typed_record_window_contract_evicts_oldest_with_bounded_sum' \
    'RecordWindowEvent.Push' \
    'record_window_count' \
    'record_window_sum' \
    'RecordWindowError.SumLimitExceeded'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordWindow::RecordWindowSession' "$docs"
rg -q 'ES-SCRIPT-031' "$ledger"
rg -q 'P11 rolling-window follow-up' "$plan"

printf 'record window audit: bounded eviction, event history, and sum accounting are present\n'
