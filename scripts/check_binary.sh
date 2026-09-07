#!/usr/bin/env bash

# Compiler-free audit for bounded binary cursors.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/binary_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'binary audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsBinary:' "$model"
rg -q 'include "\.\./runtime/binary_model\.elisa"' "$ir"
for declaration in \
    'const enum BinaryByteOrder of u8' \
    'const enum BinaryCursorState of u8' \
    'const enum BinaryEvent of u8' \
    'struct BinaryPolicy:' \
    'struct BinaryCursor:' \
    'error BinaryError:' \
    'def validate_binary_cursor\(' \
    'def binary_read_u8\(' \
    'def binary_read_u16\(' \
    'def binary_read_u32\(' \
    'def advance_binary\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'BINARY_MAX_INPUT_BYTES' \
    'BINARY_MAX_READS' \
    'BinaryByteOrder.Little' \
    'BinaryByteOrder.Big' \
    'BinaryError.Truncated' \
    'BinaryError.TrailingBytes' \
    'BinaryError.ReadLimitExceeded' \
    'BinaryError.InvalidState'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsBinary' \
    'typed_binary_contract_checks_endianness_and_trailing_bytes' \
    'BinaryByteOrder.Little' \
    'BinaryByteOrder.Big' \
    'BinaryError.Truncated'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsBinary::BinaryCursor' "$docs"
rg -q 'ES-SCRIPT-052' "$ledger"
rg -q 'P8 binary-data follow-up' "$plan"

printf 'binary audit: bounded endian reads, truncation checks, and explicit finish are present\n'
