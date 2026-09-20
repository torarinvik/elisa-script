#!/usr/bin/env bash

# Compiler-free audit for exact map-concatenation capacity admission.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
bytecode="$repo_root/src/bytecode/bytecode.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$interpreter" "$bytecode" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || {
        printf 'map concat capacity audit: missing %s\n' "$required_file" >&2
        exit 1
    }
done

assert_exact_preflight() {
    local file="$1"
    local definition="$2"
    local body
    local count_line
    local preflight_line
    local allocate_line
    body="$(awk -v definition="$definition" '
        $0 ~ definition { inside = 1 }
        inside { print }
        inside && /^        def / && $0 !~ definition { exit }
    ' "$file")"
    count_line="$(printf '%s\n' "$body" | awk '/additional: mutable usize = 0/ { print NR; exit }')"
    preflight_line="$(printf '%s\n' "$body" | awk '/runtime_storage_two_pair_spans_u32_valid\(storage, left\.map_count\.usize\(\), additional\)/ { print NR; exit }')"
    allocate_line="$(printf '%s\n' "$body" | awk '/start: u32 = storage.count.u32\(\)/ { print NR; exit }')"
    [[ "$count_line" =~ ^[0-9]+$ && "$preflight_line" =~ ^[0-9]+$ && "$allocate_line" =~ ^[0-9]+$ ]] || {
        printf 'map concat capacity audit: missing exact preflight markers in %s\n' "$file" >&2
        exit 1
    }
    (( count_line < preflight_line && preflight_line < allocate_line )) || {
        printf 'map concat capacity audit: map copy precedes exact preflight in %s\n' "$file" >&2
        exit 1
    }
}

assert_exact_preflight "$interpreter" 'def evaluate_concat'
assert_exact_preflight "$bytecode" 'def bytecode_direct_concat'
rg -q 'Map concatenation likewise counts only right-hand keys' "$docs"
rg -q 'preflights only newly introduced right-hand keys' "$ledger"

printf 'map concat capacity audit: duplicate-only merges do not require unused pair capacity\n'
