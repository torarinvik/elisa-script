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
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$network_model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'network session audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsNetworkSession:' \
    'NETWORK_SESSION_MAX_POLLS' \
    'NETWORK_SESSION_MAX_REDIRECTS' \
    'const enum NetworkSessionState of u8:' \
    'const enum NetworkSessionEvent of u8:' \
    'struct NetworkSession:' \
    'error NetworkSessionError:' \
    'def validate_network_session(' \
    'def advance_network_session('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'session_state_active' \
    'SendAccountingInvalid' \
    'ReceiveLimitExceeded' \
    'PollLimitExceeded' \
    'RedirectLimitExceeded' \
    'RetryNotReady' \
    'CancelNotReady' \
    'StatusFailure'; do
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
    'NetworkSessionEvent.CancelAck'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsNetworkSession binds those policies to one transport attempt' "$docs"
rg -Fq 'ES-SCRIPT-011 | EsNetworkSession' "$ledger"
rg -Fq 'explicit EsNetworkSession contract' "$plan"

printf 'network session audit: ordered transport phases, bounded send/receive accounting, polls, outcomes, retry, and cancellation are present\n'
