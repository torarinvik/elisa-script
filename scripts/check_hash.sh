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
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'hash audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsHash:' "$model"
rg -q 'include "\.\./runtime/hash_model\.elisa"' "$ir"
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
    rg -q "$declaration" "$model"
done

for boundary in \
    'HASH_MAX_INPUT_BYTES' \
    'HASH_MAX_CHUNK_BYTES' \
    'HASH_MAX_CHUNKS' \
    'HashAlgorithm.Sha256' \
    'HashAlgorithm.Sha512' \
    'HashError.DigestAlgorithmMismatch' \
    'HashError.DigestAlreadyPublished' \
    'hash_digest_unpublished_valid' \
    'DigestAlreadyPublished if not hash_digest_unpublished_valid' \
    'HashError.InputLimitExceeded' \
    'HashError.AccountingInvalid' \
    'digest.word1 == 0'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsHash' \
    'typed_hash_contract_bounds_chunks_and_publishes_one_digest' \
    'HashAlgorithm.Sha256' \
    'HashError.DigestAlgorithmMismatch' \
    'HashState.Finalized' \
    'HashError.AccountingInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsHash::HashContext' "$docs"
rg -q 'ES-SCRIPT-051' "$ledger"
rg -q 'P8 integrity follow-up' "$plan"

printf 'hash audit: bounded incremental algorithms, chunks, and one-shot digest publication are present\n'
