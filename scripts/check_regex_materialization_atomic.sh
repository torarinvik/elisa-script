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
    local body
    body="$(awk -v definition="$definition" '
        $0 ~ definition { inside = 1 }
        inside { print }
        inside && /^        def / && $0 !~ definition { exit }
    ' "$interpreter")"
    [[ "$body" == *"storage_start: usize = storage.count"* ]] || {
        printf 'regex materialization audit: missing entry cursor in %s\n' "$definition" >&2
        exit 1
    }
    [[ "$body" == *"storage.truncate(storage_start)"* ]] || {
        printf 'regex materialization audit: missing rollback in %s\n' "$definition" >&2
        exit 1
    }
    [[ "$body" == *"regex_work_account(machine, budget)"* ]] || {
        printf 'regex materialization audit: missing matcher budget check in %s\n' "$definition" >&2
        exit 1
    }
}

assert_atomic 'def evaluate_regex_split'
assert_atomic 'def evaluate_regex_find'
rg -q 'regex_split_value\(storage, regex_text\.text, regex_pattern\.text\)' "$bytecode"
rg -q 'regex_find_value\(storage, regex_text\.text, regex_pattern\.text\)' "$bytecode"
rg -q 'split_regex' "$interpreter_fixture"
rg -q 'find_regex' "$bytecode_fixture"
rg -q 'failed regex' "$docs"
rg -q 'failure-atomic' "$docs"
rg -q 'RegexSplit.*roll back' "$ledger"
rg -q 'check_regex_materialization_atomic\.sh' "$plan"

printf 'regex materialization audit: split/find roll back partial flat storage on matcher-budget failure\n'
