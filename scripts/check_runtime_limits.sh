#!/usr/bin/env bash

# Compiler-free audit for backend-shared execution depth limits. The reference
# interpreter and direct bytecode may use different dispatch loops, but their
# host-recursion boundary is one runtime contract and must not drift.

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
runtime_file="$repo_root/src/ir/runtime_model.elisa"
interpreter_file="$repo_root/src/ir/interpret.elisa"
bytecode_file="$repo_root/src/bytecode/bytecode.elisa"
bytecode_fixture="$repo_root/test/ir/elisascript_bytecode_test.elisa"
ir_docs="$repo_root/docs/ir.md"

for required_file in "$runtime_file" "$interpreter_file" "$bytecode_file" "$bytecode_fixture" "$ir_docs"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'runtime limit audit: missing file: %s\n' "$required_file" >&2
        exit 2
    fi
done

for shared_constant in 'ES_RUNTIME_DEFAULT_MAX_EXECUTION_CALL_DEPTH: usize = 4096' 'ES_RUNTIME_DEFAULT_MAX_VALUE_EQUAL_DEPTH: usize = 128' 'ES_RUNTIME_DEFAULT_MAX_ERROR_GUARD_DEPTH: usize = 4096'; do
    if ! rg -q "^        const $shared_constant$" "$runtime_file"; then
        printf 'runtime limit audit: shared constant is missing or changed: %s\n' "$shared_constant" >&2
        exit 1
    fi
done

if rg -q 'INTERPRET_MAX_VALUE_EQUAL_DEPTH|BYTECODE_MAX_VALUE_EQUAL_DEPTH|BYTECODE_MAX_ERROR_GUARD_DEPTH' "$interpreter_file" "$bytecode_file"; then
    printf 'runtime limit audit: backend-local shared resource constant leaked back in\n' >&2
    exit 1
fi

if rg -q 'INTERPRET_MAX_EXECUTION_CALL_DEPTH|BYTECODE_MAX_EXECUTION_CALL_DEPTH' "$interpreter_file" "$bytecode_file"; then
    printf 'runtime limit audit: backend-local execution depth constant leaked back in\n' >&2
    exit 1
fi

if ! rg -q 'ES_RUNTIME_DEFAULT_MAX_EXECUTION_CALL_DEPTH' "$interpreter_file"; then
    printf 'runtime limit audit: interpreter does not consume the shared depth limit\n' >&2
    exit 1
fi
if ! rg -q 'ES_RUNTIME_DEFAULT_MAX_EXECUTION_CALL_DEPTH' "$bytecode_file"; then
    printf 'runtime limit audit: direct bytecode does not consume the shared depth limit\n' >&2
    exit 1
fi
if ! rg -q 'ES_RUNTIME_DEFAULT_MAX_VALUE_EQUAL_DEPTH' "$interpreter_file"; then
    printf 'runtime limit audit: interpreter does not consume the shared equality depth limit\n' >&2
    exit 1
fi
if ! rg -q 'ES_RUNTIME_DEFAULT_MAX_VALUE_EQUAL_DEPTH' "$bytecode_file"; then
    printf 'runtime limit audit: direct bytecode does not consume the shared equality depth limit\n' >&2
    exit 1
fi
if ! rg -q 'ES_RUNTIME_DEFAULT_MAX_ERROR_GUARD_DEPTH' "$interpreter_file"; then
    printf 'runtime limit audit: interpreter does not consume the shared error-guard depth limit\n' >&2
    exit 1
fi
if ! rg -q 'ES_RUNTIME_DEFAULT_MAX_ERROR_GUARD_DEPTH' "$bytecode_file"; then
    printf 'runtime limit audit: direct bytecode does not consume the shared error-guard depth limit\n' >&2
    exit 1
fi
if ! rg -q 'right\.integer >= instruction\.result_type\.bits\.i64\(\)' "$bytecode_file"; then
    printf 'runtime limit audit: direct bytecode shift guard is not width-aware\n' >&2
    exit 1
fi
if ! rg -q 'invalid_u8_shift' "$bytecode_fixture" || ! rg -q 'failure == InterpretError\.InvalidShift' "$bytecode_fixture"; then
    printf 'runtime limit audit: width-specific direct-bytecode shift regression is missing\n' >&2
    exit 1
fi
if ! rg -q 'ES_RUNTIME_DEFAULT_MAX_EXECUTION_CALL_DEPTH' "$ir_docs" || ! rg -q 'host-recursive|host recursive|handler/error-stack depth' "$ir_docs"; then
    printf 'runtime limit audit: IR documentation omits the shared call-depth contract\n' >&2
    exit 1
fi

for safe_guard in \
    'usage.elapsed_micros > policy.elapsed_micros' \
    'amount > policy.elapsed_micros - usage.elapsed_micros' \
    'usage.memory_bytes > policy.memory_bytes' \
    'amount > policy.memory_bytes - usage.memory_bytes' \
    'usage.output_bytes > policy.output_bytes' \
    'amount > policy.output_bytes - usage.output_bytes' \
    'usage.regex_work > policy.regex_work' \
    'amount > policy.regex_work - usage.regex_work' \
    'usage.retained_traces > policy.retained_traces' \
    'amount > policy.retained_traces - usage.retained_traces'; do
    if ! rg -q "$safe_guard" "$runtime_file"; then
        printf 'runtime limit audit: missing ordered budget guard: %s\n' "$safe_guard" >&2
        exit 1
    fi
done

printf 'runtime limit audit: interpreter and direct bytecode share execution depth contract\n'
