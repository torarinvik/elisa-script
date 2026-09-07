#!/usr/bin/env bash

# Compiler-free audit for bounded child-environment snapshots.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/environment_model.elisa"
process_model="$repo_root/src/runtime/process_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$process_model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'environment audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsEnvironment:' \
    'ENVIRONMENT_MAX_ENTRIES' \
    'ENVIRONMENT_MAX_TEXT_BYTES' \
    'const enum EnvironmentState of u8:' \
    'const enum EnvironmentEvent of u8:' \
    'struct EnvironmentEntry:' \
    'struct EnvironmentSnapshot:' \
    'error EnvironmentContractError:' \
    'def validate_environment_snapshot(' \
    'def environment_lookup(' \
    'def advance_environment_snapshot('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'environment_name_valid' \
    'environment_value_valid' \
    'environment_add_fits' \
    'DuplicateName' \
    'NameMissing' \
    'LookupNotReady' \
    'AccountingInvalid' \
    'ResetNotReady'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/environment_model.elisa"' "$ir"
rg -Fq 'using EsEnvironment' "$fixture"
for fixture_pattern in \
    'typed_environment_snapshot_contract_is_bounded_and_tombstone_stable' \
    'EnvironmentEvent.Set' \
    'EnvironmentEvent.Unset' \
    'environment_lookup' \
    'EnvironmentContractError.NameMissing'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsEnvironment provides the child-facing data boundary' "$docs"
rg -Fq 'ES-SCRIPT-010 | EsEnvironment' "$ledger"
rg -Fq 'explicit EsEnvironment snapshot contract' "$plan"

printf 'environment audit: bounded unique entries, sealed lookup, deterministic set/unset overlays, tombstones, and reset are present\n'
