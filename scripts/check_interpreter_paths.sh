#!/usr/bin/env bash

# Compiler-free audit for interpreter POSIX path admission.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
fixture="$repo_root/test/ir/elisascript_interpreter_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$interpreter" "$fixture" "$docs" "$ledger" "$plan"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'interpreter path audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q 'const INTERPRET_MAX_PATH_BYTES: usize = 4096' "$interpreter"
rg -q 'def path_text_valid\(' "$interpreter"
rg -q 'return false if length == 0 or length >= INTERPRET_MAX_PATH_BYTES' "$interpreter"
rg -q 'return not text_has_nul\(value\)' "$interpreter"
rg -q 'def nul_terminated_path\(' "$interpreter"
rg -q 'return \[\] if not path_text_valid\(value\)' "$interpreter"
rg -q 'c_path: dstr = nul_terminated_path\(' "$interpreter"
rg -q 'c_source: dstr = nul_terminated_path\(' "$interpreter"
rg -q 'c_target: dstr = nul_terminated_path\(' "$interpreter"
rg -q 'working_directory_bytes <- nul_terminated_path\(' "$interpreter"
rg -q 'not path_text_valid\(working_directory\.text\)' "$interpreter"

if rg -q 'c_(path|source|destination|target|link): dstr = nul_terminated_text\(' "$interpreter"; then
    printf 'interpreter path audit: a filesystem c-string still bypasses path admission\n' >&2
    exit 1
fi

for forbidden in \
    'sview_len(path.text) == 0 or text_has_nul(path.text)' \
    'sview_len(source.text) == 0 or sview_len(destination.text) == 0 or text_has_nul(source.text)' \
    'sview_len(source) == 0 or sview_len(destination) == 0 or text_has_nul(source)' \
    'sview_len(path) == 0 or text_has_nul(path)'; do
    if rg -Fq "$forbidden" "$interpreter"; then
        printf 'interpreter path audit: unbounded path NUL scan remains: %s\n' "$forbidden" >&2
        exit 1
    fi
done

rg -q 'interpreter_rejects_oversized_path_before_c_string_allocation' "$fixture"
rg -q 'sview\("", 0, 4096\)' "$fixture"
rg -q 'All filesystem text and byte operations reject an empty path' "$docs"
rg -q '4 KiB path admission|4096-byte path|interpreter.*path' "$docs"
rg -q 'ES-FS-001' "$ledger"
rg -q 'interpret\.elisa' "$ledger"
rg -q 'interpreter.*path' "$plan"

printf 'interpreter path audit: bounded path admission precedes C-string scans and host calls\n'
