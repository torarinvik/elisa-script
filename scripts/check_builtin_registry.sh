#!/usr/bin/env bash

# Compiler-free audit for the first shared typed-builtin registry slice. This
# checks that the registry rows are complete and that semantic/lowering code
# consumes the same metadata for every registered spelling.

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
registry_file="$repo_root/vendor/elisa-compiler/src/semantic/builtin_registry.elisa"
semantic_file="$repo_root/vendor/elisa-compiler/src/semantic/symbols.elisa"
lowerer_file="$repo_root/src/ir/lower_ast.elisa"
opcode_file="$repo_root/src/ir/ir_model.elisa"

for required_file in "$registry_file" "$semantic_file" "$lowerer_file" "$opcode_file"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'builtin registry audit: missing file: %s\n' "$required_file" >&2
        exit 2
    fi
done

registry_names="$(sed -n '/def typed_builtin_names/,/^        def /p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
method_names="$(sed -n '/def typed_builtin_method_names/,$p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
if [[ -z "$registry_names" ]]; then
    printf 'builtin registry audit: typed_builtin_names is empty\n' >&2
    exit 1
fi
if [[ -z "$method_names" ]]; then
    printf 'builtin registry audit: typed_builtin_method_names is empty\n' >&2
    exit 1
fi

for name in $registry_names; do
    if ! rg -q "name == \"$name\"" "$registry_file"; then
        printf 'builtin registry audit: %s has no typed spec row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "callee_name == \"$name\"" "$lowerer_file"; then
        printf 'builtin registry audit: lowerer has no dispatch branch for %s\n' "$name" >&2
        exit 1
    fi
    if rg -q "add_symbol\(\"$name\"" "$semantic_file"; then
        printf 'builtin registry audit: %s is re-seeded outside the typed registry loop\n' "$name" >&2
        exit 1
    fi
    opcode="$(sed -n "s/.*name: \"$name\".*opcode: \"\([A-Za-z0-9_]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$opcode" ]] || ! rg -q "^[[:space:]]*$opcode$" "$opcode_file"; then
        printf 'builtin registry audit: %s has no declared IR opcode (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
    argument_types="$(sed -n "s/.*name: \"$name\".*argument_types: \"\([^\"]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$argument_types" ]]; then
        printf 'builtin registry audit: %s has no argument-type descriptor\n' "$name" >&2
        exit 1
    fi
done

if ! rg -q 'typed_builtin_method_spec\("Text", method_name\)' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no receiver-method registry consumer\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_call_shape\("Text", method_name' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no receiver-method shape consumer\n' >&2
    exit 1
fi

for name in $method_names; do
    if ! rg -q "known: true, name: \"$name\", receiver: \"Text\"" "$registry_file"; then
        printf 'builtin registry audit: Text.%s has no receiver-specific registry row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "method_name == \"$name\"" "$lowerer_file"; then
        printf 'builtin registry audit: lowerer has no Text method branch for %s\n' "$name" >&2
        exit 1
    fi
done

if ! rg -q 'typed_builtin_spec\(builtin_name\)' "$semantic_file"; then
    printf 'builtin registry audit: semantic seed table does not consume typed_builtin_spec\n' >&2
    exit 1
fi

if ! rg -q 'argument_types: builtin_spec\.argument_types' "$semantic_file" || \
   ! rg -q 'effects: builtin_spec\.effects' "$semantic_file" || \
   ! rg -q 'errors: builtin_spec\.errors' "$semantic_file" || \
   ! rg -q 'opcode: builtin_spec\.opcode' "$semantic_file"; then
    printf 'builtin registry audit: semantic symbols do not preserve full builtin metadata\n' >&2
    exit 1
fi

# The strict scalar/text rows must source their result types from the registry;
# this prevents a lowerer branch from silently drifting from semantic metadata.
if ! rg -q "typed_builtin_spec\(callee_name\)\.return_type" "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no registry return-type consumer\n' >&2
    exit 1
fi

if ! rg -q 'typed_builtin_spec\(callee_name\)\.errors' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no registry error-row consumer\n' >&2
    exit 1
fi

printf 'builtin registry audit: %s global and %s Text receiver spellings share semantic and lowerer metadata\n' "$(printf '%s\n' "$registry_names" | awk 'NF {count += 1} END {print count + 0}')" "$(printf '%s\n' "$method_names" | awk 'NF {count += 1} END {print count + 0}')"
