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
ir_docs="$repo_root/docs/ir.md"

for required_file in "$runtime_file" "$interpreter_file" "$bytecode_file" "$ir_docs"; do
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
if ! rg -q 'ES_RUNTIME_DEFAULT_MAX_EXECUTION_CALL_DEPTH' "$ir_docs" || ! rg -q 'host-recursive|host recursive|handler/error-stack depth' "$ir_docs"; then
    printf 'runtime limit audit: IR documentation omits the shared call-depth contract\n' >&2
    exit 1
fi

printf 'runtime limit audit: interpreter and direct bytecode share execution depth contract\n'
