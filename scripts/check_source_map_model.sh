#!/usr/bin/env bash

# Compiler-free audit for bounded cross-module source maps.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/source_map_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'source map audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsSourceMap:' \
    'SOURCE_MAP_MAX_ENTRIES' \
    'const enum SourceMapState of u8:' \
    'const enum SourceMapEvent of u8:' \
    'struct SourceLocation:' \
    'struct SourceMapEntry:' \
    'struct SourceMap:' \
    'error SourceMapContractError:' \
    'def validate_source_map(' \
    'def advance_source_map(' \
    'def source_map_lookup('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'EntryOrderInvalid' \
    'DuplicateFile' \
    'FileIndexInvalid' \
    'map.state == SourceMapState.Empty' \
    'AppendNotReady' \
    'source_location_before' \
    'map.state == SourceMapState.Invalid'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/source_map_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_source_map_contract_orders_locations_and_supports_lookup' \
    'SourceMapEvent.Begin' \
    'SourceMapEvent.Seal' \
    'SourceMapContractError.AppendNotReady' \
    'forged_empty'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsSourceMap` gives diagnostics and navigation a bounded identity layer' "$docs"
rg -Fq 'P14 source-map follow-up' "$plan"

printf 'source map audit: bounded file identity, ordered locations, sealing, and lookup are present\n'
