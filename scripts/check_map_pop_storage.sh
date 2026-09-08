#!/usr/bin/env bash

# Compiler-free audit for storage-neutral absent-key PopMap behavior.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
bytecode="$repo_root/src/bytecode/bytecode.elisa"
interpreter_fixture="$repo_root/test/ir/elisascript_interpreter_test.elisa"
bytecode_fixture="$repo_root/test/ir/elisascript_bytecode_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$interpreter" "$bytecode" "$interpreter_fixture" "$bytecode_fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'map pop storage audit: missing %s\n' "$required_file" >&2; exit 1; }
done

assert_search_before_allocate() {
    local file="$1"
    local definition="$2"
    local body
    local search_line
    local allocate_line

    body="$(awk -v definition="$definition" '
        $0 ~ definition { inside = 1 }
        inside { print }
        inside && /^        def / && $0 !~ definition { exit }
    ' "$file")"
    [[ "$body" == *"return collection if not found"* ]] || {
        printf 'map pop storage audit: missing absent-key return in %s\n' "$file" >&2
        exit 1
    }
    search_line="$(printf '%s\n' "$body" | awk '/return collection if not found/ { print NR; exit }')"
    allocate_line="$(printf '%s\n' "$body" | awk '/start: u32 = storage.count.u32\(\)/ { print NR; exit }')"
    [[ "$search_line" =~ ^[0-9]+$ && "$allocate_line" =~ ^[0-9]+$ ]] || {
        printf 'map pop storage audit: missing search/allocation markers in %s\n' "$file" >&2
        exit 1
    }
    (( search_line < allocate_line )) || {
        printf 'map pop storage audit: allocation precedes absent-key return in %s\n' "$file" >&2
        exit 1
    }
}

rg -q '^        def evaluate_pop_map\(' "$interpreter"
rg -q '^        def bytecode_direct_pop_map\(' "$bytecode"
assert_search_before_allocate "$interpreter" 'def evaluate_pop_map'
assert_search_before_allocate "$bytecode" 'def bytecode_direct_pop_map'
rg -q 'runtime_storage_pairs_u32_valid\(storage, collection\.map_count\.usize\(\) - 1\)' "$interpreter"
rg -q 'runtime_storage_pairs_u32_valid\(storage, collection\.map_count\.usize\(\) - 1\)' "$bytecode"

rg -q 'interpreter_executes_python_dictionary_pop_with_default' "$interpreter_fixture"
rg -q 'assert storage\.count == 2' "$interpreter_fixture"
rg -q 'bytecode_direct_python_dictionary_pop_matches_reference_interpreter' "$bytecode_fixture"
rg -q 'reference_storage\.count == reference_storage_before_fallback \+ 2' "$bytecode_fixture"
rg -q 'bytecode_storage\.count == bytecode_storage_before_fallback \+ 2' "$bytecode_fixture"

rg -q 'absent-key `PopMap`' "$docs"
rg -q 'absent-key removal leaves flat storage unchanged' "$ledger"
rg -q 'backend parity follow-up' "$plan"

printf 'map pop storage audit: both backends search before allocation and fixtures bound absent-key storage growth\n'
