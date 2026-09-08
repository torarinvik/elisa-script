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
rg -q 'source_info: mutable ElisascriptStat = zeroed' "$interpreter"
rg -q 'destination_info: mutable ElisascriptStat = zeroed' "$interpreter"
rg -q 'elisascript_posix_stat\(source_items\.cast\[cstr\], source_info\)' "$interpreter"
rg -q 'elisascript_posix_stat\(destination_items\.cast\[cstr\], destination_info\)' "$interpreter"
rg -q 'source_info\.device == destination_info\.device and source_info\.inode == destination_info\.inode' "$interpreter"
rg -q 'source_exists and destination_exists' "$interpreter"
rg -q 'exactly identical source and destination|self-copy|self copy' "$docs"
rg -q 'hard.link|hard link|same file|inode|alias' "$docs"
rg -q 'exactly identical source and|self-copy|self copy' "$ledger"
rg -q 'hard.link|hard link|same file|inode|alias' "$ledger"
rg -q 'self-copy|self copy|copy_path.*identical|identical.*copy_path' "$plan"

printf 'copy-path audit: identical source/destination is rejected before truncating open\n'
