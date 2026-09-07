#!/usr/bin/env bash

# Compiler-free audit for bounded literal regex-replacement quoting.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
source_file="$repo_root/src/ir/interpret.elisa"
fixture_file="$repo_root/test/ir/elisascript_interpreter_test.elisa"
docs_file="$repo_root/docs/ir.md"
plan_file="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$source_file" "$fixture_file" "$docs_file" "$plan_file"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'regex replacement audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

for boundary in \
    'def regex_quote_replacement(' \
    'regex_replacement_within_budget' \
    'byte == 92' \
    'byte == 36' \
    'byte == 38' \
    'def regex_replace_text(' \
    'sview_at(replacement, index + 1) == 92'; do
    if ! rg -Fq "$boundary" "$source_file"; then
        printf 'regex replacement audit: missing %s\n' "$boundary" >&2
        exit 1
    fi
done

rg -q 'interpreter_quotes_literal_regex_replacement_text' "$fixture_file"
rg -q 'regex_quote_replacement' "$docs_file"
rg -q 'P11 literal replacement follow-up' "$plan_file"

printf 'regex replacement audit: literal quoting, escaped backslashes, and bounded output are present\n'
