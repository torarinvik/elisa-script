#!/usr/bin/env bash

# Compiler-free audit for failure-atomic regex array materialization.
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
    [[ -f "$required_file" ]] || { printf 'regex materialization audit: missing %s\n' "$required_file" >&2; exit 1; }
done

assert_atomic() {
    local definition="$1"
    local collection="$2"
    local body
    local local_line
    local preflight_line
    local result_line
    local push_line
    body="$(awk -v definition="$definition" '
        $0 ~ definition { inside = 1 }
        inside { print }
        inside && /^        def / && $0 !~ definition { exit }
    ' "$interpreter")"
    local_line="$(printf '%s\n' "$body" | awk -v collection="$collection" 'index($0, collection ": mutable darray[RegexMatchSpan] = []") { print NR; exit }')"
    preflight_line="$(printf '%s\n' "$body" | awk -v collection="$collection" 'index($0, "runtime_storage_span_u32_valid(storage, " collection ".count)") { print NR; exit }')"
    result_line="$(printf '%s\n' "$body" | awk '/result_start: u32 = storage.count.u32\(\)/ { print NR; exit }')"
    push_line="$(printf '%s\n' "$body" | awk '/storage\.push\(runtime_text/ { print NR; exit }')"
    [[ "$local_line" =~ ^[0-9]+$ && "$preflight_line" =~ ^[0-9]+$ && "$result_line" =~ ^[0-9]+$ && "$push_line" =~ ^[0-9]+$ ]] || {
        printf 'regex materialization audit: missing local span/preflight markers in %s\n' "$definition" >&2
        exit 1
    }
    (( local_line < preflight_line && preflight_line < result_line && result_line < push_line )) || {
        printf 'regex materialization audit: shared storage is touched before exact preflight in %s\n' "$definition" >&2
        exit 1
    }
    [[ "$body" == *"regex_work_account(machine, budget)"* ]] || {
        printf 'regex materialization audit: missing matcher budget check in %s\n' "$definition" >&2
        exit 1
    }
}

assert_atomic 'def evaluate_regex_split' 'fields'
assert_atomic 'def evaluate_regex_find' 'matches'
rg -q 'regex_split_value\(storage, regex_text\.text, regex_pattern\.text\)' "$bytecode"
rg -q 'regex_find_value\(storage, regex_text\.text, regex_pattern\.text\)' "$bytecode"
rg -q 'split_regex' "$interpreter_fixture"
rg -q 'find_regex' "$bytecode_fixture"
rg -q 'exact result count' "$docs"
rg -q 'failure-atomic' "$docs"
rg -q 'exact result count' "$ledger"
rg -q 'RegexSplit.*roll back' "$ledger"
rg -q 'check_regex_materialization_atomic\.sh' "$plan"

printf 'regex materialization audit: split/find preflight exact local span counts before publication\n'
