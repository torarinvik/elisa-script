#!/usr/bin/env bash

# Compiler-free audit for bounded network transport sessions.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/network_session_model.elisa"
network_model="$repo_root/src/runtime/network_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$network_model" "$ir" "$fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'network session audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsNetworkSession:' \
    'Limits::POLLS' \
    'Limits::REDIRECTS' \
    'const enum NetworkSessionState of u8:' \
    'const enum NetworkSessionEvent of u8:' \
    'struct NetworkSession:' \
    'current_url_from_redirect' \
    'error NetworkSessionError:' \
    'def validate_network_session(' \
    'def network_session_effective_request_headers(' \
    'def advance_network_session('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'session_state_active' \
    'SendAccountingInvalid' \
    'ReceiveLimitExceeded' \
    'PollLimitExceeded' \
    'RedirectLimitExceeded' \
    'network_request_effective_headers(session.request, session.current_method, session.current_body_bytes, session.current_url_from_redirect, session.strip_sensitive_headers)' \
    'session.current_url_from_redirect <- true' \
    'session.current_url_from_redirect <- false' \
    'RedirectNotAllowed' \
    'InvalidRedirectStatus' \
    'RetryNotReady' \
    'CancelNotReady' \
    'session_state_requires_attempt' \
    'session_state_requires_attempt(session.state) and session.attempts == 0' \
    'outcome == NetworkOutcome.Cancelled' \
    'StatusFailure' \
    'NetworkSessionState.Planned and' \
    'NetworkSessionState.Completed and' \
    'session.sent_bytes != session.request.body.count' \
    'NetworkSessionState.Failed and' \
    'session.outcome == NetworkOutcome.StatusFailure' \
    'session_state_active(session.state) and' \
    'NetworkSessionState.Cancelled'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/network_session_model.elisa"' "$ir"
rg -Fq 'using EsNetworkSession' "$fixture"
for fixture_pattern in \
    'typed_network_session_contract_accounts_send_receive_and_cancel' \
    'NetworkSessionEvent.DnsReady' \
    'NetworkSessionEvent.SendComplete' \
    'NetworkSessionEvent.ReceiveChunk' \
    'NetworkSessionEvent.ReceiveComplete' \
    'NetworkSessionEvent.Redirect' \
    'network_session_effective_request_headers' \
    'partial_effective_body_rejected' \
    'original_post_headers.count == 8' \
    'rewritten_post_headers.count == 4' \
    'rewritten_chunked_headers.count == 0' \
    'cross_origin_headers.count == 2' \
    'retry_redirect.current_url_from_redirect' \
    'retry_headers.count == 4' \
    'NetworkSessionError.RedirectNotAllowed' \
    'NetworkSessionEvent.CancelAck' \
    'NetworkSessionError.AccountingInvalid'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsNetworkSession binds those policies to one transport attempt' "$docs"
rg -Fq 'ES-SCRIPT-011 | EsNetworkSession' "$ledger"

printf 'network session audit: ordered transport phases, bounded send/receive accounting, redirects, polls, outcomes, retry, and cancellation are present\n'
