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

if ! rg -q '^        const ES_RUNTIME_DEFAULT_MAX_EXECUTION_CALL_DEPTH: usize = 4096$' "$runtime_file"; then
    printf 'runtime limit audit: shared execution depth constant is missing or changed\n' >&2
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
if ! rg -q 'ES_RUNTIME_DEFAULT_MAX_EXECUTION_CALL_DEPTH' "$ir_docs" || ! rg -q 'host-recursive|host recursive|handler/error-stack depth' "$ir_docs"; then
    printf 'runtime limit audit: IR documentation omits the shared call-depth contract\n' >&2
    exit 1
fi

printf 'runtime limit audit: interpreter and direct bytecode share execution depth contract\n'
