#!/usr/bin/env bash

# Compiler-free audit for bounded regex replacement and character-class behavior.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
source_file="$repo_root/src/ir/interpret.elisa"
bytecode_file="$repo_root/src/bytecode/bytecode.elisa"
fixture_file="$repo_root/test/ir/elisascript_interpreter_test.elisa"
bytecode_fixture_file="$repo_root/test/ir/elisascript_bytecode_test.elisa"
docs_file="$repo_root/docs/ir.md"

for required_file in "$source_file" "$bytecode_file" "$fixture_file" "$bytecode_fixture_file" "$docs_file"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'regex replacement audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

for ordered_guard in \
    'if start > end:' \
    'if end > sview_len(value):' \
    'if output.count > INTERPRET_MAX_TEXT_REPLACEMENT_BYTES:'; do
    if ! rg -Fq "$ordered_guard" "$source_file"; then
        printf 'regex replacement audit: missing ordered guard %s\n' "$ordered_guard" >&2
        exit 1
    fi
done
rg -Fq 'return false if start > end' "$bytecode_file"
rg -Fq 'return false if end > sview_len(value)' "$bytecode_file"
rg -Fq 'return false if output.count > Limits::TEXT_OUTPUT_BYTES' "$bytecode_file"
rg -Fq 'false return if start > text_length' "$bytecode_file"
rg -Fq 'false return if separator_length > text_length - start' "$bytecode_file"

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
rg -q 'regex_machine_accepts_a_leading_close_bracket_in_character_classes' "$fixture_file"
rg -q 'bytecode_direct_regex_leading_close_bracket_matches_reference_interpreter' "$bytecode_fixture_file"
rg -Fq 'cursor <- cursor + 1 if cursor < sview_len(pattern) and sview_at(pattern, cursor) == 93' "$source_file"
rg -q 'regex_quote_replacement' "$docs_file"

printf 'regex audit: replacement quoting, bounded output, and leading class-bracket support are present\n'
