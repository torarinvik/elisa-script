#!/usr/bin/env bash

# Compiler-free audit for deterministic package registry candidates.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/package_registry_model.elisa"
package_model="$repo_root/src/runtime/package_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$package_model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'package registry audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsPackageRegistry:' \
    'PACKAGE_REGISTRY_MAX_ENTRIES' \
    'const enum PackageRegistryState of u8:' \
    'const enum PackageRegistryEvent of u8:' \
    'struct PackageCandidate:' \
    'struct PackageRegistry:' \
    'error PackageRegistryError:' \
    'def validate_package_registry(' \
    'def package_registry_find(' \
    'def advance_package_registry('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'registry_candidate_before' \
    'registry_candidate_equal' \
    'registry_constraint_satisfied' \
    'IntegrityMissing' \
    'OrderInvalid' \
    'RegistryNotReady' \
    'ConstraintNoMatch' \
    'CancelNotReady'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/package_registry_model.elisa"' "$ir"
rg -Fq 'using EsPackageRegistry' "$fixture"
for fixture_pattern in \
    'typed_package_registry_contract_is_ordered_verified_and_constraint_aware' \
    'PackageRegistryEvent.Add' \
    'package_registry_find' \
    'PackageRegistryError.OrderInvalid' \
    'PackageRegistryEvent.Cancel'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsPackageRegistry makes that adapter boundary explicit' "$docs"
rg -Fq 'ES-SCRIPT-004 | EsPackageRegistry' "$ledger"
rg -Fq 'explicit EsPackageRegistry contract' "$plan"

printf 'package registry audit: bounded integrity candidates, deterministic ordering, sealed lookup, constraints, and cancellation are present\n'
