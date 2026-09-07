#!/usr/bin/env bash

# Compiler-free audit for differential resource and cleanup comparison.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
source_file="$repo_root/src/testing/differential.elisa"
fixture_file="$repo_root/test/differential/elisascript_differential_test.elisa"
docs_file="$repo_root/docs/differential-testing.md"
plan_file="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$source_file" "$fixture_file" "$docs_file" "$plan_file"; do
    [[ -f "$required_file" ]] || { printf 'differential resource audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'const enum DifferentialResourceDifferenceKind of u8:' \
    'struct DifferentialResourceComparison:' \
    'def compare_differential_resource_usage('; do
    rg -Fq "$declaration" "$source_file"
done

for boundary in \
    'resource_policy_known' \
    'OpenHandles' \
    'ConcurrentTasks' \
    'resource snapshots are not known for both runs' \
    'open-handle cleanup usage differs'; do
    rg -Fq "$boundary" "$source_file"
done

for fixture_pattern in \
    'differential_resource_comparison_contract_reports_known_cleanup_differences' \
    'DifferentialResourceDifferenceKind.Equal' \
    'DifferentialResourceDifferenceKind.OpenHandles' \
    'DifferentialResourceDifferenceKind.Unknown'; do
    rg -Fq "$fixture_pattern" "$fixture_file"
done

rg -Fq 'compare_differential_resource_usage' "$docs_file"
rg -Fq 'P13 resource-parity follow-up' "$plan_file"

printf 'differential resource audit: known/unknown resource snapshots and cleanup counters are compared explicitly\n'
