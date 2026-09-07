#!/usr/bin/env bash

# Compiler-free audit for typed differential shrink evidence.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
source_file="$repo_root/src/testing/differential.elisa"
fixture_file="$repo_root/test/differential/elisascript_differential_test.elisa"
docs_file="$repo_root/docs/differential-testing.md"
plan_file="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$source_file" "$fixture_file" "$docs_file" "$plan_file"; do
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
    'MismatchCategory' \
    'MinimalityUnproven' \
    'candidate_fingerprint' \
    'preserved_kind'; do
    rg -Fq "$boundary" "$source_file"
done

for fixture_pattern in \
    'differential_shrink_trace_contract_records_preserved_category_and_minimality' \
    'DifferentialShrinkTraceEvent.Record' \
    'DifferentialShrinkTraceError.MismatchCategory' \
    'exhausted: true'; do
    rg -Fq "$fixture_pattern" "$fixture_file"
done

rg -Fq 'DifferentialShrinkTrace' "$docs_file"
rg -Fq 'P13 shrink-trace follow-up' "$plan_file"

printf 'differential shrink-trace audit: bounded category-preserving steps and explicit minimality proof are present\n'
