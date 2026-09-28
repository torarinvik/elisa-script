#!/usr/bin/env bash

# Compiler-free source audit for bounded HTTP Link pagination projection.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/network_pagination_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'network pagination audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsNetworkPagination:' \
    'const module Limits:' \
    'LINK_VALUES' \
    'PARAMETERS' \
    'struct NetworkPaginationResult:' \
    'error NetworkPaginationError:' \
    'const enum LinkFieldScanState of u8:' \
    'def network_pagination_next_page('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'LinkValueLimitExceeded' \
    'ParameterLimitExceeded' \
    'DuplicateRelationParameter' \
    'MultipleNextLinks' \
    'HttpsDowngrade' \
    'LinkFieldScanState.QuotedEscape' \
    'network_url_same_origin' \
    'network_request_effective_headers' \
    'credentials_stripping_active'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/network_pagination_model.elisa"' "$ir"
rg -Fq 'using EsNetworkPagination' "$fixture"
for fixture_pattern in \
    'typed_network_link_pagination_projects_next_page_request' \
    'part, one' \
    'cross_page.credentials_stripping_active' \
    'later_page.credentials_stripping_active' \
    'NetworkPaginationError.MultipleNextLinks' \
    'NetworkPaginationError.HttpsDowngrade'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsNetworkPagination` converts one validated 2xx GET response' "$docs"
rg -Fq 'ES-SCRIPT-056 | EsNetworkPagination' "$ledger"

printf 'network pagination audit: bounded Link parsing, next-page projection, origin redaction, and downgrade refusal are present\n'
