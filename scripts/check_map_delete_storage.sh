#!/usr/bin/env bash

# Compiler-free audit for storage-neutral missing-key map DeleteIndex behavior.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
bytecode="$repo_root/src/bytecode/bytecode.elisa"
interpreter_fixture="$repo_root/test/ir/elisascript_interpreter_test.elisa"
bytecode_fixture="$repo_root/test/ir/elisascript_bytecode_test.elisa"
docs="$repo_root/docs/ir.md"
semantics="$repo_root/docs/semantics.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$interpreter" "$bytecode" "$interpreter_fixture" "$bytecode_fixture" "$docs" "$semantics" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'map delete storage audit: missing %s\n' "$required_file" >&2; exit 1; }
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
        printf 'map delete storage audit: missing absent-key return in %s\n' "$file" >&2
        exit 1
    }
    search_line="$(printf '%s\n' "$body" | awk '/return collection if not found/ { print NR; exit }')"
    allocate_line="$(printf '%s\n' "$body" | awk '/start: u32 = storage.count.u32\(\)/ { print NR; exit }')"
    [[ "$search_line" =~ ^[0-9]+$ && "$allocate_line" =~ ^[0-9]+$ ]] || {
        printf 'map delete storage audit: missing search/allocation markers in %s\n' "$file" >&2
        exit 1
    }
    (( search_line < allocate_line )) || {
        printf 'map delete storage audit: allocation precedes absent-key return in %s\n' "$file" >&2
        exit 1
    }
}

rg -q '^        def evaluate_delete_index\(' "$interpreter"
rg -q '^        def bytecode_direct_delete_index\(' "$bytecode"
assert_search_before_allocate "$interpreter" 'def evaluate_delete_index'
assert_search_before_allocate "$bytecode" 'def bytecode_direct_delete_index'
rg -q 'runtime_storage_pairs_u32_valid\(storage, collection\.map_count\.usize\(\)\)' "$interpreter"
rg -q 'runtime_storage_pairs_u32_valid\(storage, collection\.map_count\.usize\(\)' "$bytecode"

rg -q 'interpreter_executes_mutable_dictionary_remove_and_clear' "$interpreter_fixture"
rg -q 'def missing\(\) -> bool' "$interpreter_fixture"
rg -q 'assert missing_storage\.count == 2' "$interpreter_fixture"
rg -q 'bytecode_mutable_dictionary_remove_matches_reference' "$bytecode_fixture"
rg -q 'missing_reference_storage\.count == 2' "$bytecode_fixture"
rg -q 'missing_bytecode_storage\.count == 2' "$bytecode_fixture"

rg -q 'missing-key' "$docs"
rg -q '`DeleteIndex` returns the original map' "$docs"
rg -q 'flat map storage unchanged' "$semantics"
rg -q 'search-before-allocation rule applies to no-op `DeleteIndex`' "$ledger"
rg -q 'check_map_delete_storage\.sh' "$plan"

printf 'map delete storage audit: both backends search before allocation and missing-key fixtures assert unchanged storage\n'
