#!/usr/bin/env bash

# Compiler-free audit for the single strict UTF-8 contract shared by source
# loading and typed text streams.

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
source="$repo_root/src/ir/source.elisa"
encoding="$repo_root/src/runtime/encoding.elisa"
stream="$repo_root/src/runtime/stream_posix.elisa"
driver="$repo_root/src/driver/elisascript.elisa"
tests="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
parser_docs="$repo_root/docs/parser.md"

for required_file in "$source" "$encoding" "$stream" "$driver" "$tests" "$docs" "$parser_docs"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'source encoding audit: missing file: %s\n' "$required_file" >&2
        exit 2
    fi
done

rg -q '^module EsEncoding:$' "$encoding"
rg -q '^        struct Utf8Cursor:$' "$encoding"
rg -q 'def utf8_feed\(' "$encoding"
rg -q 'def utf8_validate\(' "$encoding"
rg -q 'def utf8_complete\(' "$encoding"
rg -q '^using EsEncoding$' "$source"
rg -q '^    InvalidUtf8$' "$source"
rg -q 'EsEncoding::utf8_validate\(source, source_length' "$source"
rg -q 'EsEncoding::utf8_complete\(source_cursor\)' "$source"
rg -q 'return "InvalidUtf8" if failure == ElisascriptSourceError\.InvalidUtf8' "$driver"
rg -q 'EsEncoding::Utf8Cursor' "$stream"
rg -q 'EsEncoding::utf8_feed' "$stream"
rg -q 'EsEncoding::utf8_validate' "$stream"
rg -q 'typed_source_encoding_contract_is_strict' "$tests"
rg -q 'EsEncoding::utf8_complete\(four\)' "$tests"
rg -q 'utf8_feed\(237u8, surrogate\)' "$tests"
rg -q 'utf8_feed\(244u8, out_of_range\)' "$tests"
rg -q 'InvalidUtf8' "$docs"
rg -q 'InvalidUtf8' "$parser_docs"

printf 'source encoding audit: one strict UTF-8 cursor serves source and stream boundaries\n'
