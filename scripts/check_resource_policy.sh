#!/usr/bin/env bash

# Compiler-free audit for the shared per-run resource-policy contract.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
runtime_model="$repo_root/src/ir/runtime_model.elisa"
interpreter="$repo_root/src/ir/interpret.elisa"
bytecode="$repo_root/src/bytecode/bytecode.elisa"
docs_file="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$runtime_model" "$interpreter" "$bytecode" "$docs_file" "$ledger"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'resource policy audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

for required_text in \
    'struct RuntimeResourcePolicy' \
    'struct RuntimeResourceUsage' \
    'runtime_resource_policy_valid' \
    'runtime_resource_usage_within_policy' \
    'runtime_resource_policy_with_step_limit' \
    'steps' 'elapsed_micros' 'memory_bytes' 'open_handles' \
    'processes' 'output_bytes' 'regex_work' 'retained_traces' \
    'concurrent_tasks' \
    'policy: RuntimeResourcePolicy' \
    'usage: RuntimeResourceUsage'; do
    if ! rg -q "$required_text" "$runtime_model"; then
        printf 'resource policy audit: runtime model omits %s\n' "$required_text" >&2
        exit 1
    fi
done

rg -q 'resource_policy: RuntimeResourcePolicy' "$interpreter"
rg -q 'resource_usage: mutable RuntimeResourceUsage' "$interpreter"
rg -q 'runtime_resource_policy_with_step_limit' "$interpreter"
rg -q 'policy: machine.resource_policy' "$interpreter"
rg -q 'usage: machine.resource_usage' "$interpreter"
rg -q 'runtime_resource_policy_with_step_limit' "$bytecode"
rg -q 'usage: usage' "$bytecode"

rg -q 'per-run' "$docs_file"
rg -q 'RuntimeResourcePolicy' "$docs_file"
rg -q 'ES-RUNTIME-001' "$ledger"
printf 'resource policy audit: shared policy, usage snapshot, and backend metadata are present\n'
