#!/usr/bin/env bash

# Compiler-free audit for failure-atomic array sorting.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
bytecode="$repo_root/src/bytecode/bytecode.elisa"
interpreter_fixture="$repo_root/test/ir/elisascript_interpreter_test.elisa"
bytecode_fixture="$repo_root/test/ir/elisascript_bytecode_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$interpreter" "$bytecode" "$interpreter_fixture" "$bytecode_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'sort atomic audit: missing %s\n' "$required_file" >&2; exit 1; }
done

assert_preflight_before_copy() {
    local file="$1"
    local definition="$2"
    local body
    local kind_line
    local start_line
    local reserve_line

    body="$(awk -v definition="$definition" '
        $0 ~ definition { inside = 1 }
        inside { print }
        inside && /^        def / && $0 !~ definition { exit }
    ' "$file")"
    kind_line="$(printf '%s\n' "$body" | awk '/value\.kind not in/ { print NR; exit }')"
    start_line="$(printf '%s\n' "$body" | awk '/result_start: u32 = storage.count.u32\(\)/ { print NR; exit }')"
    reserve_line="$(printf '%s\n' "$body" | awk '/storage\.reserve\(/ { print NR; exit }')"
    [[ "$kind_line" =~ ^[0-9]+$ && "$start_line" =~ ^[0-9]+$ && "$reserve_line" =~ ^[0-9]+$ ]] || {
        printf 'sort atomic audit: missing scalar preflight markers in %s\n' "$file" >&2
        exit 1
    }
    (( kind_line < start_line && kind_line < reserve_line )) || {
        printf 'sort atomic audit: sort copies before scalar preflight in %s\n' "$file" >&2
        exit 1
    }
}

rg -q '^        def evaluate_sort_array\(' "$interpreter"
rg -q '^        def bytecode_direct_sort_array\(' "$bytecode"
assert_preflight_before_copy "$interpreter" 'def evaluate_sort_array'
assert_preflight_before_copy "$bytecode" 'def bytecode_direct_sort_array'
rg -q 'values\.sort\(\)' "$interpreter_fixture"
rg -q 'sorted\(\[1i64, 3i64, 2i64\]' "$bytecode_fixture"
rg -q 'preflight' "$docs"
rg -q 'scalar homogeneity' "$docs"
rg -q '`SortArray` preflights scalar element homogeneity' "$ledger"

printf 'sort atomic audit: both backends preflight scalar homogeneity before copying arrays\n'
