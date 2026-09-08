#!/usr/bin/env bash

# Compiler-free audit for failure-atomic aggregate construction.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$interpreter" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'aggregate literal atomic audit: missing %s\n' "$required_file" >&2; exit 1; }
done

assert_rollback() {
    local definition="$1"
    local body
    body="$(awk -v definition="$definition" '
        $0 ~ definition { inside = 1 }
        inside { print }
        inside && /^        def / && $0 !~ definition { exit }
    ' "$interpreter")"
    [[ "$body" == *"storage_start: usize = storage.count"* ]] || {
        printf 'aggregate literal atomic audit: missing entry cursor in %s\n' "$definition" >&2
        exit 1
    }
    [[ "$body" == *"storage.truncate(storage_start)"* ]] || {
        printf 'aggregate literal atomic audit: missing rollback in %s\n' "$definition" >&2
        exit 1
    }
}

assert_rollback 'def evaluate_array'
assert_rollback 'def evaluate_map'
global_body="$(awk '
    /def global_value\(/ { inside = 1 }
    inside { print }
    inside && /^        def / && $0 !~ /def global_value\(/ { exit }
' "$interpreter")"
global_rollbacks="$(printf '%s\n' "$global_body" | rg -c 'storage\.truncate\(start\)')"
[[ "$global_rollbacks" -ge 2 ]] || {
    printf 'aggregate literal atomic audit: global aggregate rollback is incomplete\n' >&2
    exit 1
}

rg -q 'rolls the shared storage cursor back' "$docs"
rg -q 'Array/map literal and global initialization paths likewise roll back' "$ledger"
rg -q 'check_aggregate_literal_atomic\.sh' "$plan"

printf 'aggregate literal atomic audit: array, map, and global construction roll back partial storage on failure\n'
