#!/usr/bin/env bash

# Compiler-free audit for quote-aware CSV/TSV streaming.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/csv_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'csv model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsCsv:' \
    'using EsData' \
    'const enum CsvStreamState of u8:' \
    'const enum CsvStreamEvent of u8:' \
    'struct CsvStream:' \
    'error CsvContractError:' \
    'def validate_csv_stream(' \
    'def advance_csv_stream('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'InputLimitExceeded' \
    'FieldBytesLimitExceeded' \
    'UnexpectedQuote' \
    'UnexpectedCharacterAfterQuote' \
    'UnexpectedEnd' \
    'AccountingInvalid' \
    'Cancelled'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/csv_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_csv_stream_contract_preserves_quotes_and_bounded_rows' \
    'CsvStreamEvent.Byte' \
    'CsvContractError.UnexpectedEnd'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsCsv`' "$docs"
rg -Fq 'Latest P08 CSV streaming follow-up' "$plan"

printf 'csv model audit: quote-aware bounded CSV/TSV stream transitions are present\n'
