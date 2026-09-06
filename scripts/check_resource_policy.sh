#!/usr/bin/env bash

# Compiler-free audit for the shared per-run resource-policy contract.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
runtime_model="$repo_root/src/ir/runtime_model.elisa"
interpreter="$repo_root/src/ir/interpret.elisa"
bytecode="$repo_root/src/bytecode/bytecode.elisa"
differential="$repo_root/src/testing/differential.elisa"
docs_file="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$runtime_model" "$interpreter" "$bytecode" "$differential" "$docs_file" "$ledger"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'resource policy audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

for required_text in \
    'struct RuntimeResourcePolicy' \
    'struct RuntimeResourceUsage' \
    'const enum RuntimeResourceCounter of u8' \
    'runtime_resource_policy_valid' \
    'runtime_resource_usage_within_policy' \
    'runtime_resource_policy_with_step_limit' \
    'runtime_resource_acquire' \
    'runtime_resource_release' \
    'runtime_resource_add_steps' \
    'runtime_resource_add_elapsed' \
    'runtime_resource_add_memory' \
    'runtime_resource_add_output' \
    'runtime_resource_add_regex_work' \
    'runtime_resource_add_retained_traces' \
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
rg -q 'def interpret_with_resource_policy' "$interpreter"
rg -q 'policy: machine.resource_policy' "$interpreter"
rg -q 'usage: machine.resource_usage' "$interpreter"
rg -q 'retained_traces <- observations.count' "$interpreter"
rg -q 'runtime_resource_usage_within_policy' "$interpreter"
rg -q 'runtime_resource_add_steps\(machine.resource_usage, machine.resource_policy, 1\)' "$interpreter"
rg -q 'step_limit > EsIr::ES_RUNTIME_DEFAULT_MAX_STEPS' "$bytecode"
rg -q 'policy.open_handles > ES_RUNTIME_DEFAULT_MAX_OPEN_HANDLES' "$runtime_model"
rg -q 'policy.steps > ES_RUNTIME_DEFAULT_MAX_STEPS' "$runtime_model"
rg -q 'policy.processes > ES_RUNTIME_DEFAULT_MAX_PROCESSES' "$runtime_model"
rg -q 'policy.concurrent_tasks > ES_RUNTIME_DEFAULT_MAX_CONCURRENT_TASKS' "$runtime_model"
rg -q 'handles_over' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'steps_over' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'processes_over' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'tasks_over' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'RuntimeResourceCounter.OpenHandle' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'RuntimeResourceCounter.Process' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'RuntimeResourceCounter.ConcurrentTask' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'runtime_resource_add_steps' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'runtime_resource_add_memory' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'runtime_resource_add_output' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'runtime_resource_add_regex_work' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'runtime_resource_add_retained_traces' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'tiny_policy: RuntimeResourcePolicy' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'tiny_usage: mutable RuntimeResourceUsage' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'not runtime_resource_acquire\(tiny_usage' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'not runtime_resource_release\(tiny_usage' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'zero_resource_policy: RuntimeResourcePolicy' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'not runtime_resource_acquire\(zero_resource_usage' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'bytecode_compatibility_entrypoints_reject_step_budget_above_shared_ceiling' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'runtime_resource_policy_with_step_limit' "$bytecode"
rg -q 'def execute_bytecode_with_resource_policy' "$bytecode"
rg -q 'def execute_bytecode_direct_only_with_resource_policy' "$bytecode"
rg -q 'retained_traces <- observations.count' "$bytecode"
rg -q 'runtime_resource_usage_within_policy' "$bytecode"
rg -q 'observation_limit: usize' "$bytecode"
rg -q 'observations.count >= observation_limit' "$bytecode"
rg -q 'policy.retained_traces' "$bytecode"
rg -q 'observation_limit > ES_RUNTIME_DEFAULT_MAX_OBSERVATIONS' "$bytecode"
rg -q 'usage: usage' "$bytecode"
rg -q 'resource_policy_known: mutable bool' "$differential"
rg -q 'resource_policy: mutable EsIr::RuntimeResourcePolicy' "$differential"
rg -q 'resource_usage: mutable EsIr::RuntimeResourceUsage' "$differential"
rg -q 'result.resource_policy <- execution.policy' "$differential"
rg -q 'result.resource_usage <- execution.usage' "$differential"

rg -q 'per-run' "$docs_file"
rg -q 'RuntimeResourcePolicy' "$docs_file"
rg -q 'ES-RUNTIME-001' "$ledger"
printf 'resource policy audit: shared policy, usage snapshot, and backend metadata are present\n'
