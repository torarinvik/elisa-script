#!/usr/bin/env bash

# Compiler-free audit for bounded differential execution-order checks.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/testing/order_model.elisa"
consumer="$repo_root/src/testing/differential.elisa"
fixture="$repo_root/test/differential/elisascript_differential_test.elisa"
docs="$repo_root/docs/differential-testing.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$consumer" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'differential order audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialOrder:' \
    'DIFFERENTIAL_ORDER_MAX_OBSERVATIONS' \
    'const enum DifferentialExecutionOrder of u8:' \
    'const enum DifferentialOrderState of u8:' \
    'const enum DifferentialOrderEvent of u8:' \
    'const enum DifferentialOrderClassification of u8:' \
    'const enum DifferentialContaminationPolicy of u8:' \
    'struct DifferentialOrderPolicy:' \
    'struct DifferentialOrderObservation:' \
    'struct DifferentialOrderSession:' \
    'error DifferentialOrderError:' \
    'def validate_differential_order_session(' \
    'def advance_differential_order_session('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'require_both_orders' \
    'initial_world_fingerprint' \
    'final_world_fingerprint' \
    'DuplicateOrder' \
    'OrderContaminationRejected' \
    'OrderIndependent' \
    'OrderDependent' \
    'WorldContaminated' \
    'expected_order_dependency' \
    'expected_world_contamination' \
    'session.has_world_contamination != expected_world_contamination'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "./order_model.elisa"' "$consumer"
rg -Fq 'using EsDifferentialOrder' "$fixture"
for fixture_pattern in \
    'differential_order_contract_detects_world_leaks_and_order_dependency' \
    'DifferentialExecutionOrder.ReferenceThenCandidate' \
    'DifferentialExecutionOrder.CandidateThenReference' \
    'DifferentialOrderClassification.OrderIndependent' \
    'DifferentialOrderClassification.WorldContaminated' \
    'DifferentialOrderError.OrderContaminationRejected' \
    'retained_leak' \
    'forged_order_flags'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsDifferentialOrder::DifferentialOrderSession' "$docs"
rg -Fq 'P13 execution-order follow-up' "$plan"

printf 'differential order audit: bounded dual-order execution, world restoration fingerprints, and contamination classification are present\n'
