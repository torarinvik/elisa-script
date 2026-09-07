#!/usr/bin/env bash

# Compiler-free audit for bounded differential first-divergence trace windows.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/trace_window_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$consumer" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'differential trace-window audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialTraceWindow:' \
    'DIFFERENTIAL_TRACE_WINDOW_MAX_STEPS' \
    'DIFFERENTIAL_TRACE_WINDOW_MAX_EVENTS' \
    'const enum DifferentialTraceWindowState of u8:' \
    'const enum DifferentialTraceWindowEvent of u8:' \
    'const enum DifferentialTraceWindowPosition of u8:' \
    'struct DifferentialTraceWindowPolicy:' \
    'struct DifferentialTraceWindowRecord:' \
    'struct DifferentialTraceWindow:' \
    'error DifferentialTraceWindowError:' \
    'def validate_differential_trace_window(' \
    'def advance_differential_trace_window(' \
    'def differential_trace_window_fingerprint('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'before_steps' \
    'after_steps' \
    'anchor_step' \
    'AnchorMissing' \
    'OutsideWindow' \
    'StepOrderInvalid' \
    'DifferentialTraceWindowPosition.Before' \
    'DifferentialTraceWindowPosition.Divergence' \
    'DifferentialTraceWindowPosition.After'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./trace_window_model.elisa"' "$consumer"
rg -Fq 'using EsDifferentialTraceWindow' "$fixture"
for fixture_pattern in \
    'differential_trace_window_contract_bounds_context_around_first_divergence' \
    'DifferentialTraceWindowEvent.Record' \
    'DifferentialTraceWindowEvent.Seal' \
    'DifferentialTraceWindowError.OutsideWindow'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsDifferentialTraceWindow::DifferentialTraceWindow' "$docs"
rg -Fq 'P13 trace-window follow-up' "$plan"

printf 'differential trace-window audit: bounded pre/anchor/post records and first-divergence context are present\n'
