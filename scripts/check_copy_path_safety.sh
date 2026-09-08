#!/usr/bin/env bash

# Compiler-free audit for the destructive self-copy guard.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$interpreter" "$docs" "$ledger" "$plan"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'copy-path audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q 'def evaluate_copy_path\(' "$interpreter"
rg -q 'if source\.text == destination\.text:' "$interpreter"
rg -U -q 'if source\.text == destination\.text:\n                machine\.failure <- InterpretFailure\.FileIo\n                return runtime_void\(\)\n            c_source: dstr = nul_terminated_path\(source\.text\)' "$interpreter"
rg -q 'copy_path.*identical|identical.*copy_path|self-copy|self copy' "$docs"
rg -q 'copy_path.*identical|identical.*copy_path|self-copy|self copy' "$ledger"
rg -q 'self-copy|self copy|copy_path.*identical|identical.*copy_path' "$plan"

printf 'copy-path audit: identical source/destination is rejected before truncating open\n'
