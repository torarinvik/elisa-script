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
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
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
    'const enum NetworkRequestState of u8:' \
    'const enum NetworkRequestEvent of u8:' \
    'struct NetworkRequestJob:' \
    'struct NetworkRequest:' \
    'struct NetworkResponse:' \
    'error NetworkContractError:' \
    'def validate_network_tls_policy(' \
    'def validate_network_retry_policy(' \
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
    'network_headers_valid' \
    'network_method_is_idempotent' \
    'network_tls_path_valid' \
    'DuplicateHeaderName' \
    'InvalidTimeout' \
    'InvalidResponseLimit' \
    'InvalidRetryAttempts' \
    'InvalidRetryBackoff' \
    'NonIdempotentRetry' \
    'InvalidTlsBundle' \
    'InvalidTlsClientIdentity' \
    'TlsPathEmbeddedNul' \
    'network_request_state_is_active' \
    'NetworkRequestEvent.CancelAck' \
    'NetworkRequestEvent.Retry' \
    'response.outcome in {NetworkOutcome.Success, NetworkOutcome.StatusFailure}' \
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
    'NetworkRequestState.Cancelling' \
    'NetworkRequestState.Cancelled' \
    'NetworkContractError.DuplicateHeaderName' \
    'NetworkContractError.InvalidTimeout' \
    'NetworkContractError.InvalidStatus'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsNetwork::NetworkRequest' "$docs"
rg -Fq 'error[NetworkContractError]' "$docs"
rg -Fq 'EsNetwork::NetworkRequest' "$ledger"
rg -Fq 'P12 network follow-up' "$plan"
rg -Fq 'P12 retry follow-up' "$plan"
rg -Fq 'P12 lifecycle follow-up' "$plan"
rg -Fq 'P12 TLS follow-up' "$plan"

printf 'network model audit: bounded request/response, retry, cancellation, and lifecycle contracts are present\n'
