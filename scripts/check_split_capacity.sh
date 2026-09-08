#!/usr/bin/env bash

# Compiler-free audit for exact text-split result capacity.
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
    [[ -f "$required_file" ]] || {
        printf 'split capacity audit: missing %s\n' "$required_file" >&2
        exit 1
    }
done

assert_publisher() {
    local file="$1"
    local definition="$2"
    local body
    local preflight_line
    local result_line
    local push_line
    body="$(awk -v definition="$definition" '
        index($0, definition) { inside = 1 }
        inside { print }
        inside && /^        def / && index($0, definition) == 0 { exit }
    ' "$file")"
    preflight_line="$(printf '%s\n' "$body" | awk '/runtime_storage_span_u32_valid\(storage, fields\.count\)/ { print NR; exit }')"
    result_line="$(printf '%s\n' "$body" | awk '/result_start: u32 = storage\.count\.u32\(\)/ { print NR; exit }')"
    push_line="$(printf '%s\n' "$body" | awk '/storage\.push\(runtime_text\(field\)\)/ { print NR; exit }')"
    [[ "$preflight_line" =~ ^[0-9]+$ && "$result_line" =~ ^[0-9]+$ && "$push_line" =~ ^[0-9]+$ ]] || {
        printf 'split capacity audit: missing publisher markers in %s\n' "$file" >&2
        exit 1
    }
    (( preflight_line < result_line && result_line < push_line )) || {
        printf 'split capacity audit: publisher touches shared storage before exact preflight in %s\n' "$file" >&2
        exit 1
    }
}

assert_split() {
    local file="$1"
    local definition="$2"
    local body
    body="$(awk -v definition="$definition" '
        index($0, definition) { inside = 1 }
        inside { print }
        inside && /^        def / && index($0, definition) == 0 { exit }
    ' "$file")"
    rg -q 'parts: mutable darray\[sview\] = \[\]' <<<"$body"
    rg -q 'publish_split_fields' <<<"$body"
    ! rg -q 'runtime_storage_text_fields_u32_valid' <<<"$body"
    ! rg -q 'storage\.push\(runtime_text' <<<"$body"
}

assert_publisher "$interpreter" 'def publish_split_fields'
assert_publisher "$bytecode" 'def bytecode_direct_publish_split_fields'
assert_split "$interpreter" 'def evaluate_split('
assert_split "$bytecode" 'def bytecode_direct_split('
rg -q 'interpreter_splits_text_into_typed_fields' "$interpreter_fixture"
rg -q 'bytecode_direct_text_fields_match_reference_interpreter' "$bytecode_fixture"
rg -q 'bytecode_direct_python_text_rsplit_matches_reference_interpreter' "$bytecode_fixture"
rg -q 'Text split, line-split, and regex result builders' "$docs"
rg -q 'General text `Split`/`rsplit` now collect local views' "$ledger"
rg -q 'check_split_capacity\.sh' "$plan"

printf 'split capacity audit: exact local field counts are preflighted before publication\n'
