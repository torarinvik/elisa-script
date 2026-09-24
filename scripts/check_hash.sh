#!/usr/bin/env bash

# Compiler-free audit for bounded incremental integrity hashing.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/hash_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
max_source_bytes=16777216
max_total_source_bytes=33554432

rg_bounded() {
    command rg --max-filesize "$max_source_bytes" "$@"
}

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger"; do
    [[ -f "$required_file" && -r "$required_file" ]] || { printf 'hash audit: missing %s\n' "$required_file" >&2; exit 1; }
done

# Keep the shell oracle within the same per-file and aggregate source bounds as
# the Elisascript port before ripgrep scans any content.
total_source_bytes=0
for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger"; do
    if ! source_size="$(wc -c < "$required_file" | tr -d '[:space:]')"; then
        printf 'hash audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
    case "$source_size" in
        ''|*[!0-9]*)
            printf 'hash audit: missing %s\n' "$required_file" >&2
            exit 1
            ;;
    esac
    source_size=$((10#$source_size))
    if (( source_size > max_source_bytes || source_size > max_total_source_bytes - total_source_bytes )); then
        printf 'hash audit: source exceeds audit limit: %s\n' "$required_file" >&2
        exit 2
    fi
    total_source_bytes=$((total_source_bytes + source_size))
done

rg_bounded -q '^module EsHash:' "$model"
rg_bounded -q 'include "\.\./runtime/hash_model\.elisa"' "$ir"
for declaration in \
    'const enum HashAlgorithm of u8' \
    'const enum HashState of u8' \
    'const enum HashEvent of u8' \
    'struct HashPolicy:' \
    'struct HashDigest:' \
    'struct HashContext:' \
    'error HashError:' \
    'def validate_hash_context\(' \
    'def advance_hash\('; do
    rg_bounded -q "$declaration" "$model"
done

for boundary in \
    'Limits::INPUT_BYTES' \
    'Limits::CHUNK_BYTES' \
    'Limits::CHUNKS' \
    'HashAlgorithm.Sha256' \
    'HashAlgorithm.Sha512' \
    'HashError.DigestAlgorithmMismatch' \
    'HashError.DigestAlreadyPublished' \
    'hash_digest_unpublished_valid' \
    'DigestAlreadyPublished if not hash_digest_unpublished_valid' \
    'HashError.InputLimitExceeded' \
    'HashError.AccountingInvalid' \
    'context.chunks_seen == 0 and context.bytes_seen != 0' \
    'context.chunks_seen != 0 and context.bytes_seen == 0' \
    'digest.word1 == 0'; do
    rg_bounded -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsHash' \
    'typed_hash_contract_bounds_chunks_and_publishes_one_digest' \
    'HashAlgorithm.Sha256' \
    'HashError.DigestAlgorithmMismatch' \
    'HashState.Finalized' \
    'HashError.AccountingInvalid'; do
    rg_bounded -q "$fixture_pattern" "$fixture_file"
done

rg_bounded -q 'EsHash::HashContext' "$docs"
rg_bounded -q 'ES-SCRIPT-051' "$ledger"

printf 'hash audit: bounded incremental algorithms, chunks, and one-shot digest publication are present\n'
