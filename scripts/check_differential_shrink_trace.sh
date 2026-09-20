#!/usr/bin/env bash

# Compiler-free audit for typed differential shrink evidence.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
source_file="$repo_root/src/testing/differential.elisa"
fixture_file="$repo_root/test/differential/elisascript_differential_test.elisa"
docs_file="$repo_root/docs/differential-testing.md"

for required_file in "$source_file" "$fixture_file" "$docs_file"; do
    [[ -f "$required_file" ]] || { printf 'differential shrink-trace audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'DIFFERENTIAL_SHRINK_TRACE_MAX_STEPS' \
    'const enum DifferentialShrinkTraceState of u8:' \
    'const enum DifferentialShrinkTraceEvent of u8:' \
    'struct DifferentialShrinkTraceStep:' \
    'struct DifferentialShrinkTrace:' \
    'error DifferentialShrinkTraceError:' \
    'def validate_differential_shrink_trace(' \
    'def advance_differential_shrink_trace('; do
    rg -Fq "$declaration" "$source_file"
done

for boundary in \
    'minimality_proven' \
    'trace.minimality_proven and trace.state != DifferentialShrinkTraceState.Complete' \
    'MismatchCategory' \
    'MinimalityUnproven' \
    'candidate_fingerprint' \
    'preserved_kind' \
    'ClearReferenceValueSlot' \
    'ClearCandidateValueSlot' \
    'differential_run_with_value_slot_cleared'; do
    rg -Fq "$boundary" "$source_file"
done

for fixture_pattern in \
    'differential_shrink_trace_contract_records_preserved_category_and_minimality' \
    'differential_run_shrinker_preserves_first_difference_and_order' \
    'DifferentialShrinkTraceEvent.Record' \
    'DifferentialShrinkTraceError.MismatchCategory' \
    'forged_shrink_proof' \
    'ClearReferenceValueSlot' \
    'ClearCandidateValueSlot' \
    'exhausted: true'; do
    rg -Fq "$fixture_pattern" "$fixture_file"
done

rg -Fq 'DifferentialShrinkTrace' "$docs_file"

printf 'differential shrink-trace audit: bounded category-preserving steps and explicit minimality proof are present\n'
