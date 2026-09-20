#!/usr/bin/env bash

# Compiler-free audit for the bounded network request/response contract.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/network_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$ledger"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'network model audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

for declaration in \
    'module EsNetwork:' \
    'const enum NetworkMethod of u8:' \
    'const enum NetworkOutcome of u8:' \
    'const enum NetworkRetryMode of u8:' \
    'struct NetworkRetryPolicy:' \
    'const enum NetworkTlsVersion of u8:' \
    'const enum NetworkTlsTrustMode of u8:' \
    'struct NetworkTlsPolicy:' \
    'const enum NetworkStreamDirection of u8:' \
    'const enum NetworkStreamState of u8:' \
    'const enum NetworkStreamEvent of u8:' \
    'struct NetworkChunk:' \
    'struct NetworkStream:' \
    'const enum NetworkRequestState of u8:' \
    'const enum NetworkRequestEvent of u8:' \
    'struct NetworkRequestJob:' \
    'struct NetworkRequest:' \
    'struct NetworkResponse:' \
    'error NetworkContractError:' \
    'def validate_network_tls_policy(' \
    'def validate_network_stream(' \
    'def advance_network_stream(' \
    'def enqueue_network_chunk(' \
    'def consume_network_stream(' \
    'def validate_network_retry_policy(' \
    'def network_retry_backoff_micros(' \
    'def advance_network_request(' \
    'def validate_network_request(' \
    'def validate_network_response('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'NETWORK_MAX_URL_BYTES' \
    'NETWORK_MAX_HEADER_BYTES' \
    'NETWORK_MAX_BODY_BYTES' \
    'NETWORK_MAX_RETRY_ATTEMPTS' \
    'NETWORK_MAX_BACKOFF_MICROS' \
    'NETWORK_MAX_TLS_PATH_BYTES' \
    'NETWORK_MAX_CHUNK_BYTES' \
    'NETWORK_MAX_BUFFER_BYTES' \
    'NETWORK_MAX_STREAM_CHUNKS' \
    'network_headers_valid' \
    'network_header_name_byte_valid' \
    'network_header_value_valid' \
    'network_header_name_byte_equal' \
    'network_header_names_equal' \
    'left_folded' \
    'network_method_is_idempotent' \
    'network_retry_backoff_micros' \
    'network_tls_path_valid' \
    'DuplicateHeaderName' \
    'HeaderValueInvalid' \
    'byte < 32u8 and byte != 9u8' \
    'InvalidTimeout' \
    'InvalidResponseLimit' \
    'InvalidRetryAttempts' \
    'InvalidRetryBackoff' \
    'NonIdempotentRetry' \
    'InvalidTlsBundle' \
    'InvalidTlsClientIdentity' \
    'TlsPathEmbeddedNul' \
    'ChunkSequenceMismatch' \
    'StreamBufferExceeded' \
    'StreamNotComplete' \
    'StreamNotDrained' \
    'StreamAccountingInvalid' \
    'stream.state == NetworkStreamState.Cancelling or stream.state == NetworkStreamState.Cancelled' \
    'network_request_state_is_active' \
    'network_request_state_requires_attempt' \
    'job.attempts > job.max_attempts' \
    'job.state == NetworkRequestState.Planned and job.attempts >= job.max_attempts' \
    'NetworkRequestEvent.CancelAck' \
    'NetworkRequestEvent.Retry' \
    'response.outcome == NetworkOutcome.Success' \
    'response.outcome == NetworkOutcome.StatusFailure' \
    'response.status < 200 or response.status > 399' \
    'response.status != 0'; do
    rg -Fq "$boundary" "$model"
done

for fixture_pattern in \
    'typed_network_contract_is_explicit_and_bounded' \
    'NetworkMethod.Post' \
    'NetworkOutcome.TlsFailure' \
    'NetworkRetryMode.IdempotentOnly' \
    'NetworkContractError.NonIdempotentRetry' \
    'NetworkTlsTrustMode.CustomBundle' \
    'NetworkContractError.InvalidTlsBundle' \
    'NetworkContractError.InvalidTlsClientIdentity' \
    'NetworkStreamEvent.Pause' \
    'NetworkStreamEvent.Finish' \
    'NetworkContractError.ChunkSequenceMismatch' \
    'NetworkContractError.StreamNotDrained' \
    'NetworkContractError.StreamAccountingInvalid' \
    'forged_cancelling_stream' \
    'NetworkRequestState.Cancelling' \
    'NetworkRequestState.Cancelled' \
    'NetworkContractError.DuplicateHeaderName' \
    'NetworkContractError.InvalidTimeout' \
    'NetworkContractError.InvalidStatus' \
    'forged_cancelled_stream' \
    'case_insensitive_headers' \
    'case_insensitive_duplicate_rejected' \
    'invalid_header_name' \
    'invalid_header_value'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'forged_success_status' "$fixture"
rg -Fq 'forged_failure_status' "$fixture"
rg -Fq 'forged_completed_outcome' "$fixture"

rg -Fq 'EsNetwork::NetworkRequest' "$docs"
rg -Fq 'error[NetworkContractError]' "$docs"
rg -Fq 'EsNetwork::NetworkRequest' "$ledger"

printf 'network model audit: bounded request/response, retry, streaming, cancellation, and lifecycle contracts are present\n'
