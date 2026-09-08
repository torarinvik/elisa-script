#!/usr/bin/env bash

# Compiler-free audit for exact split-lines result capacity.
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
        printf 'split-lines capacity audit: missing %s\n' "$required_file" >&2
        exit 1
    }
done

assert_exact() {
    local file="$1"
    local definition="$2"
    local body
    local local_line
    local preflight_line
    local result_line
    local push_line
    body="$(awk -v definition="$definition" '
        $0 ~ definition { inside = 1 }
        inside { print }
        inside && /^        def / && $0 !~ definition { exit }
    ' "$file")"
    local_line="$(printf '%s\n' "$body" | awk 'index($0, "fields: mutable darray[sview] = []") { print NR; exit }')"
    preflight_line="$(printf '%s\n' "$body" | awk 'index($0, "runtime_storage_span_u32_valid(storage, fields.count)") { print NR; exit }')"
    result_line="$(printf '%s\n' "$body" | awk '/start: u32 = storage.count.u32\(\)/ { print NR; exit }')"
    push_line="$(printf '%s\n' "$body" | awk '/storage\.push\(runtime_text\(field\)\)/ { print NR; exit }')"
    [[ "$local_line" =~ ^[0-9]+$ && "$preflight_line" =~ ^[0-9]+$ && "$result_line" =~ ^[0-9]+$ && "$push_line" =~ ^[0-9]+$ ]] || {
        printf 'split-lines capacity audit: missing exact result markers in %s\n' "$file" >&2
        exit 1
    }
    (( local_line < preflight_line && preflight_line < result_line && result_line < push_line )) || {
        printf 'split-lines capacity audit: shared storage is touched before exact preflight in %s\n' "$file" >&2
        exit 1
    }
}

assert_exact "$interpreter" 'def evaluate_split_lines'
assert_exact "$bytecode" 'def bytecode_direct_split_lines'
rg -q 'split_lines' "$interpreter_fixture"
rg -q 'splitlines' "$bytecode_fixture"
rg -q 'Line splitting also counts its actual fields' "$docs"
rg -q '`SplitLines` now applies the same exact-result admission' "$ledger"
rg -q 'check_split_lines_capacity\.sh' "$plan"

printf 'split-lines capacity audit: actual fields are preflighted before publication\n'
