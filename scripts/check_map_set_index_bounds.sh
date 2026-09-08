#!/usr/bin/env bash

# Compiler-free audit for bounded map SetIndex materialization.
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
    [[ -f "$required_file" ]] || { printf 'map set-index bounds audit: missing %s\n' "$required_file" >&2; exit 1; }
done

assert_preflight_before_allocate() {
    local file="$1"
    local definition="$2"
    local body
    local ceiling_line
    local span_line
    local allocate_line

    body="$(awk -v definition="$definition" '
        $0 ~ definition { inside = 1 }
        inside { print }
        inside && /^        def / && $0 !~ definition { exit }
    ' "$file")"
    ceiling_line="$(printf '%s\n' "$body" | awk '/collection\.map_count == 4294967295u32/ { print NR; exit }')"
    span_line="$(printf '%s\n' "$body" | awk '/runtime_storage_pairs_u32_valid\(storage, collection\.map_count\.usize\(\) \+ 1\)/ { print NR; exit }')"
    allocate_line="$(printf '%s\n' "$body" | awk '/start: u32 = storage.count.u32\(\)/ { print NR; exit }')"
    [[ "$ceiling_line" =~ ^[0-9]+$ && "$span_line" =~ ^[0-9]+$ && "$allocate_line" =~ ^[0-9]+$ ]] || {
        printf 'map set-index bounds audit: missing preflight markers in %s\n' "$file" >&2
        exit 1
    }
    (( ceiling_line < allocate_line && span_line < allocate_line )) || {
        printf 'map set-index bounds audit: allocation precedes preflight in %s\n' "$file" >&2
        exit 1
    }
}

rg -q '^        def evaluate_set_index\(' "$interpreter"
rg -q '^        def bytecode_direct_set_index\(' "$bytecode"
assert_preflight_before_allocate "$interpreter" 'def evaluate_set_index'
assert_preflight_before_allocate "$bytecode" 'def bytecode_direct_set_index'

rg -q 'values.*two.*<-' "$interpreter_fixture"
rg -q 'values.*two.*<-' "$bytecode_fixture"
rg -q 'Indexed map updates preflight' "$docs"
rg -q '`SetIndex` map updates also preflight' "$ledger"
rg -q 'check_map_set_index_bounds\.sh' "$plan"

printf 'map set-index bounds audit: reference and direct backends preflight map capacity before copying\n'
