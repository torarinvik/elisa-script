#!/usr/bin/env bash

# Compiler-free audit for shell-free executable discovery.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/executable_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'executable audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsExecutable:' "$model"
rg -q 'include "\.\./runtime/executable_model\.elisa"' "$ir"
for declaration in \
    'const enum ExecutableDiscoveryState of u8' \
    'const enum ExecutableDiscoveryEvent of u8' \
    'struct ExecutableDiscoveryRequest:' \
    'struct ExecutableCandidate:' \
    'struct Executable:' \
    'struct ExecutableDiscoverySession:' \
    'error ExecutableDiscoveryError:' \
    'def validate_executable_discovery\(' \
    'def executable_discovery_result\(' \
    'def advance_executable_discovery\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'EXECUTABLE_MAX_NAME_BYTES' \
    'EXECUTABLE_MAX_PATH_ENTRIES' \
    'EXECUTABLE_MAX_CANDIDATES' \
    'ExecutableDiscoveryEvent.Candidate' \
    'ExecutableDiscoveryError.MissingNotReady' \
    'ExecutableDiscoveryError.CandidateOrderInvalid' \
    'ExecutableDiscoveryState.Found' \
    'ExecutableDiscoveryState.Missing'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsExecutable' \
    'typed_executable_discovery_contract_distinguishes_path_and_executable' \
    'ExecutableDiscoveryEvent.Candidate' \
    'ExecutableDiscoveryError.MissingNotReady' \
    'executable_discovery_result'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsExecutable::ExecutableDiscoverySession' "$docs"
rg -q 'ES-SCRIPT-041' "$ledger"
rg -q 'P10 executable-discovery follow-up' "$plan"

printf 'executable audit: bounded PATH candidate and executable identity protocol is present\n'
