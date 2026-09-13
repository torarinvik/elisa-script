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
    'runtime_resource_remaining_policy' \
    'runtime_resource_policy_has_unaccounted_dimensions' \
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
rg -q 'runtime_resource_policy_has_unaccounted_dimensions\(policy\)' "$interpreter"
rg -q 'def interpret_with_resource_policy' "$interpreter"
rg -q 'policy: machine.resource_policy' "$interpreter"
rg -q 'usage: machine.resource_usage' "$interpreter"
rg -q 'retained_traces <- observations.count' "$interpreter"
rg -q 'runtime_resource_usage_within_policy' "$interpreter"
rg -q 'runtime_resource_add_steps\(machine.resource_usage, machine.resource_policy, 1\)' "$interpreter"
rg -q 'runtime_resource_add_output\(machine.resource_usage, machine.resource_policy, writer.offset\)' "$interpreter"
rg -q 'runtime_resource_add_output\(machine.resource_usage, machine.resource_policy, host_size\)' "$interpreter"
rg -q 'def process_resource_acquire\(' "$interpreter"
rg -q 'def process_resource_complete\(' "$interpreter"
rg -q 'waiter.reaped <- true' "$interpreter"
process_admission_sites="$(rg -F -c 'if not process_resource_acquire(machine)' "$interpreter")"
if [[ "$process_admission_sites" != "4" ]]; then
    printf 'resource policy audit: expected four accounted interpreter fork paths, found %s\n' "$process_admission_sites" >&2
    exit 1
fi
process_completion_sites="$(rg -F -c 'if not process_resource_complete(machine, waiter)' "$interpreter")"
if [[ "$process_completion_sites" != "4" ]]; then
    printf 'resource policy audit: expected four child-reap accounting paths, found %s\n' "$process_completion_sites" >&2
    exit 1
fi
for lease_helper in interpret_open_file interpret_open_tmpfile interpret_close_file interpret_open_directory interpret_close_directory; do
    if ! rg -q "def ${lease_helper}\\(" "$interpreter"; then
        printf 'resource policy audit: interpreter omits %s\n' "$lease_helper" >&2
        exit 1
    fi
done
rg -q 'RuntimeResourceCounter.OpenHandle' "$interpreter"
# Keep every raw libc/POSIX stream acquisition and release inside the lease
# helpers. This catches a future bridge that would otherwise bypass the
# per-machine active-handle ceiling.
for raw_host_edge in 'fopen(' 'fclose(' 'elisascript_posix_tmpfile(' 'elisascript_posix_opendir(' 'elisascript_posix_closedir(' 'elisascript_posix_mkstemp(' 'elisascript_posix_close('; do
    raw_edge_count="$(rg -F -o "$raw_host_edge" "$interpreter" | wc -l | tr -d '[:space:]')"
    if [[ "$raw_edge_count" != "1" ]]; then
        printf 'resource policy audit: expected one leased host edge %s, found %s\n' "$raw_host_edge" "$raw_edge_count" >&2
        exit 1
    fi
done
rg -q 'read_owned_directory\(machine: mutable Machine&' "$interpreter"
rg -q 'def regex_work_account\(' "$interpreter"
rg -q 'runtime_resource_add_regex_work\(machine.resource_usage, machine.resource_policy, delta\)' "$interpreter"
rg -q 'regex_work_budget_limit\(machine\)' "$interpreter"
rg -q 'const INTERPRET_MAX_REGEX_WORK: u64 = ES_RUNTIME_DEFAULT_MAX_REGEX_WORK' "$interpreter"
rg -q 'consumed: mutable u64 = 0' "$interpreter"
rg -q 'remaining: u64 = reader.limit - current' "$interpreter"
rg -q 'capacity <- remaining.usize\(\)' "$interpreter"
rg -Fq 'elisascript_posix_read(0, (&chunk[0]).cast[mutable void&], capacity)' "$interpreter"
rg -Fq 'reader.consumed <- reader.consumed + count.u64()' "$interpreter"
rg -Fq 'if not stdio_read_append_fits(reader, 1)' "$interpreter"
rg -Fq 'reader.consumed <- reader.consumed + 1' "$interpreter"
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
rg -q 'partial_usage: RuntimeResourceUsage' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'runtime_resource_remaining_policy\(partial_usage, policy\)' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'exhausted_remaining: RuntimeResourcePolicy' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'unattached_usage: RuntimeResourceUsage' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'tiny_policy: RuntimeResourcePolicy' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'tiny_usage: mutable RuntimeResourceUsage' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'not runtime_resource_acquire\(tiny_usage' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'not runtime_resource_release\(tiny_usage' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'handle_limited: RuntimeResourcePolicy' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'zero_resource_policy: RuntimeResourcePolicy' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'not runtime_resource_acquire\(zero_resource_usage' "$repo_root/test/ir/elisascript_ir_test.elisa"
rg -q 'bytecode_compatibility_entrypoints_reject_step_budget_above_shared_ceiling' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'bytecode_strict_direct_entrypoint_rejects_unaccounted_resource_dimensions' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'bytecode_process_zero_budget_routes_to_accounted_interpreter' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'reference\.usage\.output_bytes == 3' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'compiled\.usage\.output_bytes == reference\.usage\.output_bytes' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'runtime_resource_policy_with_step_limit' "$bytecode"
rg -q 'runtime_resource_remaining_policy' "$runtime_model"
rg -q 'def execute_bytecode_with_resource_policy' "$bytecode"
rg -q 'def execute_bytecode_direct_only_with_resource_policy' "$bytecode"
rg -q 'def bytecode_policy_requires_reference' "$bytecode"
rg -q 'policy.processes != ES_RUNTIME_DEFAULT_MAX_PROCESSES' "$bytecode"
rg -q 'def bytecode_policy_has_unsupported_dimensions' "$bytecode"
rg -q 'runtime_resource_policy_has_unaccounted_dimensions\(policy\)' "$bytecode"
rg -q 'bytecode_policy_requires_reference\(policy\)' "$bytecode"
rg -q 'bytecode_policy_has_unsupported_dimensions\(policy\)' "$bytecode"
rg -q 'retained_traces <- observations.count' "$bytecode"
rg -q 'runtime_resource_usage_within_policy' "$bytecode"
rg -q 'observation_limit: usize' "$bytecode"
rg -q 'observations.count >= observation_limit' "$bytecode"
rg -q 'module.globals.count > ES_RUNTIME_DEFAULT_MAX_STORAGE_VALUES' "$interpreter"
rg -q 'module.globals.count > ES_RUNTIME_DEFAULT_MAX_STORAGE_VALUES' "$bytecode"
rg -q 'bytecode_direct_global_values\(module: BytecodeModule&' "$bytecode"
rg -q 'bytecode_scalar_globals_execute_direct_with_shared_state' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'runtime_storage_span_u32_valid\(storage, binding.aggregate_values.count\)' "$bytecode"
rg -q 'bytecode_flat_literal_collection_globals_execute_direct' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'bytecode_direct_i16_u16_i32_u32_match_reference' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'output_base: usize = 0' "$bytecode"
rg -q 'output_bytes: mutable usize&' "$bytecode"
rg -q 'def execute_bytecode_direct_with_ledger' "$bytecode"
rg -q 'output_ledger: mutable usize&' "$bytecode"
rg -q 'nested: Execution = try execute_bytecode_direct_with_ledger' "$bytecode"
rg -q 'observation_limit, output_bytes\)' "$bytecode"
rg -q 'output_bytes <- nested.usage.output_bytes' "$bytecode"
rg -q 'output_bytes: output_ledger' "$bytecode"
rg -q 'cursor.output_bytes <- output_ledger' "$bytecode"
rg -q 'output_ledger <- cursor.output_bytes' "$bytecode"
rg -q 'bytecode_direct_nested_process_output_is_accounted_once' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'recovered_direct.usage.output_bytes == recovered_reference.usage.output_bytes' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
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
