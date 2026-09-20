#!/usr/bin/env bash

# Compiler-free audit for failure-atomic Path.iterdir materialization.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
bytecode="$repo_root/src/bytecode/bytecode.elisa"
fixture="$repo_root/test/ir/elisascript_interpreter_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$interpreter" "$bytecode" "$fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'path iterdir atomic audit: missing %s\n' "$required_file" >&2; exit 1; }
done

body="$(awk '
    /def evaluate_path_iterdir\(/ { inside = 1 }
    inside { print }
    inside && /^        def / && $0 !~ /def evaluate_path_iterdir\(/ { exit }
' "$interpreter")"
[[ "$body" == *"storage_start: usize = storage.count"* ]] || {
    printf 'path iterdir atomic audit: missing entry cursor\n' >&2
    exit 1
}
truncate_count="$(printf '%s\n' "$body" | rg -c 'storage\.truncate\(storage_start\)')"
[[ "$truncate_count" -ge 2 ]] || {
    printf 'path iterdir atomic audit: late failures do not roll back storage\n' >&2
    exit 1
}
rg -q 'if not path_join_length_fits' <<<"$body"
rg -q 'if not path_shape_result_valid' <<<"$body"
rg -q 'path_iterdir_value\(storage, path_value\.text\)' "$bytecode"
rg -q 'interpreter_executes_python_path_iterdir_with_hidden_entries' "$fixture"
rg -q 'Path\.iterdir\(\).*validates every joined child path' "$docs"
rg -q 'Path\.iterdir\(\)' "$ledger"
rg -q 'failure-atomic' "$ledger"

printf 'path iterdir atomic audit: late child-path failures roll back shared storage before publication\n'
