#!/usr/bin/env bash

# Compiler-free audit for exact regex capture result capacity.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
interpreter_fixture="$repo_root/test/ir/elisascript_interpreter_test.elisa"
bytecode_fixture="$repo_root/test/ir/elisascript_bytecode_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$interpreter" "$interpreter_fixture" "$bytecode_fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || {
        printf 'regex capture capacity audit: missing %s\n' "$required_file" >&2
        exit 1
    }
done

body="$(awk '
    /def evaluate_regex_capture\(/ { inside = 1 }
    inside { print }
    inside && /^        def / && $0 !~ /def evaluate_regex_capture\(/ { exit }
' "$interpreter")"
matcher_line="$(printf '%s\n' "$body" | awk '/regex_work_account\(machine, budget\)/ { line = NR } END { print line }')"
exact_line="$(printf '%s\n' "$body" | awk '/runtime_storage_span_u32_valid\(storage, result_count\)/ { print NR; exit }')"
pattern_charge_line="$(printf '%s\n' "$body" | awk '/runtime_storage_text_fields_u32_valid\(storage, sview_len\(pattern\.text\)\)/ { print NR; exit }')"
[[ "$matcher_line" =~ ^[0-9]+$ && "$exact_line" =~ ^[0-9]+$ && -z "$pattern_charge_line" ]] || {
    printf 'regex capture capacity audit: exact post-match sizing is incomplete\n' >&2
    exit 1
}
(( matcher_line < exact_line )) || {
    printf 'regex capture capacity audit: exact sizing precedes matcher accounting\n' >&2
    exit 1
}

rg -q 'capture_regex' "$interpreter_fixture"
rg -q 'capture_regex' "$bytecode_fixture"
named_body="$(awk '
    /def evaluate_regex_capture_named\(/ { inside = 1 }
    inside { print }
    inside && /^        def / && $0 !~ /def evaluate_regex_capture_named\(/ { exit }
' "$interpreter")"
[[ "$named_body" != *"runtime_storage_text_fields_u32_valid"* ]] || {
    printf 'regex capture capacity audit: scalar named lookup still charges text-field storage\n' >&2
    exit 1
}
rg -q 'sizes the exact proven group/name result' "$docs"
rg -q 'exact proven' "$ledger"
rg -q 'check_regex_capture_capacity\.sh' "$plan"

printf 'regex capture capacity audit: exact proven result slots are preflighted after matcher accounting\n'
