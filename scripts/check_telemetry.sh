#!/usr/bin/env bash

# Compiler-free audit for bounded optional telemetry.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/telemetry_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'telemetry audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsTelemetry:' "$model"
rg -q 'include "\.\./runtime/telemetry_model\.elisa"' "$ir"
for declaration in \
    'const enum TelemetryMode of u8' \
    'const enum TelemetryState of u8' \
    'const enum TelemetryEventKind of u8' \
    'const enum TelemetryEvent of u8' \
    'struct TelemetryPolicy:' \
    'struct TelemetryMetric:' \
    'struct TelemetryTraceEvent:' \
    'struct TelemetryLedger:' \
    'error TelemetryError:' \
    'def validate_telemetry_ledger\(' \
    'def advance_telemetry\(' \
    'def telemetry_record_metric\(' \
    'def telemetry_append_event\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'TELEMETRY_MAX_METRICS' \
    'TELEMETRY_MAX_EVENTS' \
    'TELEMETRY_MAX_NAME_BYTES' \
    'TELEMETRY_MAX_PAYLOAD_BYTES' \
    'TELEMETRY_MAX_SPANS' \
    'TelemetryMode.Disabled' \
    'TelemetryRecordOutcome.Sampled' \
    'TelemetryError.EventLimitExceeded' \
    'TelemetryError.SpanAccountingInvalid' \
    'TelemetryError.AccountingInvalid' \
    'TelemetryError.TelemetryDisabled'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsTelemetry' \
    'typed_telemetry_contract_bounds_metrics_spans_and_sampling' \
    'TelemetryMode.Events' \
    'TelemetryRecordOutcome.Sampled' \
    'TelemetryError.TelemetryDisabled' \
    'TelemetryState.Failed' \
    'TelemetryError.AccountingInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsTelemetry::TelemetryLedger' "$docs"
rg -q 'ES-SCRIPT-045' "$ledger"
rg -q 'P6 telemetry follow-up' "$plan"

printf 'telemetry audit: opt-out metrics, sampled events, and bounded span accounting are present\n'
