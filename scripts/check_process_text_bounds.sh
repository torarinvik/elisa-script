#!/usr/bin/env bash

# Compiler-free audit for process/environment text admission ordering.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
docs_file="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$interpreter" "$docs_file" "$ledger"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'process text bounds audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q 'def process_text_length_fits\(machine: Machine&, value: sview\)' "$interpreter"
rg -q 'return true if machine\.process_argument_bytes_limit == 0' "$interpreter"
rg -q 'return sview_len\(value\) < machine\.process_argument_bytes_limit' "$interpreter"
rg -q 'if not process_text_length_fits\(machine, value\.text\)' "$interpreter"
rg -q 'if not process_text_length_fits\(machine, executable\.text\)' "$interpreter"
rg -q 'if not process_text_length_fits\(machine, argument\.text\)' "$interpreter"
rg -q 'if not process_text_length_fits\(machine, name\.text\) or not process_text_length_fits\(machine, value\.text\)' "$interpreter"
rg -q 'if text_has_nul\(executable\.text\)' "$interpreter"
rg -q 'if text_has_nul\(argument\.text\)' "$interpreter"
rg -q 'if text_has_nul\(name\.text\) or sview_contains_byte\(name\.text, 61\) or text_has_nul\(value\.text\)' "$interpreter"

if rg -q 'or text_has_nul\(executable\.text\)' "$interpreter"; then
    printf 'process text bounds audit: executable NUL scan remains fused with type admission\n' >&2
    exit 1
fi
if rg -q 'or text_has_nul\(argument\.text\)' "$interpreter"; then
    printf 'process text bounds audit: argument NUL scan remains fused with type admission\n' >&2
    exit 1
fi
if rg -q 'or text_has_nul\(name\.text\)' "$interpreter"; then
    printf 'process text bounds audit: environment NUL scan remains fused with type admission\n' >&2
    exit 1
fi

rg -q 'per-field length admission|process_text_length_fits|borrowed.*NUL' "$docs_file"
rg -q 'pre-scan|process_text_length_fits|process text' "$ledger"
printf 'process text bounds audit: per-field process and environment admission precedes host scans\n'
