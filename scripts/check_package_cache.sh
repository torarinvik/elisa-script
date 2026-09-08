#!/usr/bin/env bash

# Compiler-free audit for exact, bounded package artifact caching.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/package_cache_model.elisa"
package_model="$repo_root/src/runtime/package_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$package_model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'package cache audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsPackageCache:' \
    'PACKAGE_CACHE_MAX_ENTRIES' \
    'PACKAGE_CACHE_MAX_BYTES' \
    'const enum PackageCacheState of u8:' \
    'const enum PackageCacheEvent of u8:' \
    'struct PackageCacheEntry:' \
    'struct PackageCache:' \
    'error PackageCacheError:' \
    'def validate_package_cache(' \
    'def package_cache_lookup(' \
    'def advance_package_cache('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'cache_entry_before' \
    'cache_entry_equal' \
    'CacheNotReady' \
    'CacheMiss' \
    'EntryIndexInvalid' \
    'InvalidateNotReady' \
    'cache.state == PackageCacheState.Empty' \
    'cache.state != PackageCacheState.Updating' \
    'ResetNotReady' \
    'ByteLimitExceeded'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/package_cache_model.elisa"' "$ir"
rg -Fq 'using EsPackageCache' "$fixture"
for fixture_pattern in \
    'typed_package_cache_contract_requires_exact_identity_and_explicit_invalidation' \
    'PackageCacheEvent.Store' \
    'package_cache_lookup' \
    'PackageCacheError.CacheMiss' \
    'PackageCacheEvent.Invalidate' \
    'forged_empty'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsPackageCache complements the registry' "$docs"
rg -Fq 'ES-SCRIPT-005 | EsPackageCache' "$ledger"
rg -Fq 'explicit EsPackageCache contract' "$plan"

printf 'package cache audit: bounded ordered entries, exact identity lookup, byte limits, invalidation, and reset transitions are present\n'
