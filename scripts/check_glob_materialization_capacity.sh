#!/usr/bin/env bash

# Compiler-free audit for exact deduplicated glob result capacity.
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
        printf 'glob materialization capacity audit: missing %s\n' "$required_file" >&2
        exit 1
    }
done

body="$(awk '
    /def evaluate_expand_glob\(/ { inside = 1 }
    inside { print }
    inside && /^        def / && $0 !~ /def evaluate_expand_glob\(/ { exit }
' "$interpreter")"
count_line="$(printf '%s\n' "$body" | awk '/unique_matches: mutable usize = 0/ { print NR; exit }')"
preflight_line="$(printf '%s\n' "$body" | awk '/runtime_storage_span_u32_valid\(storage, unique_matches\)/ { print NR; exit }')"
allocate_line="$(printf '%s\n' "$body" | awk '/start: u32 = storage.count.u32\(\)/ { print NR; exit }')"
[[ "$count_line" =~ ^[0-9]+$ && "$preflight_line" =~ ^[0-9]+$ && "$allocate_line" =~ ^[0-9]+$ ]] || {
    printf 'glob materialization capacity audit: missing unique-count markers\n' >&2
    exit 1
}
(( count_line < preflight_line && preflight_line < allocate_line )) || {
    printf 'glob materialization capacity audit: publication precedes unique-count preflight\n' >&2
    exit 1
}

rg -q 'variant_bytes > INTERPRET_MAX_GLOB_VARIANT_BYTES' "$interpreter"
rg -q 'sview_len\(pattern\) > INTERPRET_MAX_GLOB_VARIANT_BYTES - variant_bytes' "$interpreter"
rg -q 'walker\.match_bytes > INTERPRET_MAX_GLOB_MATCH_BYTES' "$interpreter"
rg -q 'length > INTERPRET_MAX_GLOB_MATCH_BYTES - walker\.match_bytes' "$interpreter"

rg -q 'expand_glob' "$interpreter_fixture"
rg -q 'expand_glob' "$bytecode_fixture"
rg -q 'Glob expansion similarly counts sorted unique matches' "$docs"
rg -q 'preflights its deduplicated match count' "$ledger"
rg -q 'check_glob_materialization_capacity\.sh' "$plan"

printf 'glob materialization capacity audit: deduplicated matches are preflighted before publication\n'
