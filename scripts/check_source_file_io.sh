#!/usr/bin/env bash

# Compiler-free audit for the exact-size source-file stdio boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
source_file="$repo_root/src/ir/source_file.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$source_file" "$docs" "$ledger" "$plan"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'source-file I/O audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q 'def elisascript_read_stream_fully\(' "$source_file"
rg -U -q 'amount == 0 or amount > remaining or ferror\(stream\) != 0' "$source_file"
rg -q 'read_count != size\.usize\(\) or close_status != 0' "$source_file"
rg -q 'sticky host error|ferror.*source|source.*ferror|source-file.*stdio' "$docs"
rg -q 'sticky host error|ferror.*source|source.*ferror|source-file.*stdio' "$ledger"
rg -q 'source-file stdio|source file.*ferror|source-file.*ferror' "$plan"

printf 'source-file I/O audit: exact-size reads reject host errors before source publication\n'
