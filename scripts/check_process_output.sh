#!/usr/bin/env bash

# Compiler-free audit for explicit process redirection and tee routing.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/process_output_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'process output audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q 'stderr_length > ES_RUNTIME_DEFAULT_MAX_OUTPUT_BYTES' "$repo_root/src/bytecode/bytecode.elisa"
rg -q 'stdout_length > ES_RUNTIME_DEFAULT_MAX_OUTPUT_BYTES - stderr_length' "$repo_root/src/bytecode/bytecode.elisa"
rg -q 'cursor.output_bytes > ES_RUNTIME_DEFAULT_MAX_OUTPUT_BYTES' "$repo_root/src/bytecode/bytecode.elisa"

rg -q '^module EsProcessOutput:' "$model"
rg -q 'include "\.\./runtime/process_output_model\.elisa"' "$ir"
for declaration in \
    'const enum ProcessOutputDestinationKind of u8' \
    'const enum ProcessOutputState of u8' \
    'const enum ProcessOutputEvent of u8' \
    'struct ProcessOutputDestination:' \
    'struct ProcessOutputRoute:' \
    'struct ProcessOutputChunk:' \
    'struct ProcessOutputSession:' \
    'error ProcessOutputError:' \
    'def validate_process_output_session\(' \
    'def advance_process_output\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'Limits::DESTINATIONS' \
    'Limits::CHUNKS' \
    'Limits::BYTES' \
    'Limits::PATH_BYTES' \
    'ProcessOutputDestinationKind.TruncateFile' \
    'ProcessOutputDestinationKind.AppendFile' \
    'ProcessOutputError.DuplicateDestination' \
    'ProcessOutputError.ChunkOrderInvalid' \
    'ProcessOutputError.AccountingInvalid' \
    'session.next_sequence != session.chunk_count' \
    'ProcessOutputState.Closed'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsProcessOutput' \
    'typed_process_output_contract_makes_redirection_and_tee_explicit' \
    'ProcessOutputDestinationKind.AppendFile' \
    'ProcessOutputError.DuplicateDestination' \
    'ProcessOutputChunk'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsProcessOutput::ProcessOutputSession' "$docs"
rg -q 'ProcessOutputError' "$ledger"

printf 'process output audit: bounded redirection, append, capture, and tee routing are present\n'
