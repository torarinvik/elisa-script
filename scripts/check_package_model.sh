#!/usr/bin/env bash

# Compiler-free audit for typed package manifests and lockfiles.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/package_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'package model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsPackage:' \
    'PACKAGE_FORMAT_VERSION' \
    'PACKAGE_MAX_LOCK_ENTRIES' \
    'const enum PackageDependencyKind of u8:' \
    'const enum PackageSourceKind of u8:' \
    'const enum PackageResolutionState of u8:' \
    'struct PackageManifest:' \
    'struct PackageLockEntry:' \
    'struct PackageLock:' \
    'error PackageContractError:' \
    'def validate_package_manifest(' \
    'def validate_package_lock(' \
    'def validate_package_resolution(' \
    'def advance_package_resolution('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'offline_only' \
    'IntegrityMissing' \
    'LockOrderInvalid' \
    'MissingLockedDependency' \
    'ConstraintUnsatisfied' \
    'package_version_equal(constraint.max_version, constraint.min_version)' \
    'ResolutionNotReady' \
    'package_constraint_satisfied'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/package_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_package_manifest_and_lock_contract_is_reproducible_and_offline_safe' \
    'PackageResolutionEvent.Lock' \
    'PackageResolutionEvent.Verify' \
    'PackageContractError.MissingLockedDependency' \
    'PackageContractError.LockOrderInvalid'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsPackage` supplies that package-facing contract' "$docs"
rg -Fq 'P14 package follow-up' "$plan"

printf 'package model audit: typed manifests, ordered lockfiles, integrity identities, offline policy, and resolution checks are present\n'
