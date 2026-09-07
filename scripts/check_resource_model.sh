#!/usr/bin/env bash

# Compiler-free audit for typed resource ownership and cleanup edges.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/resource_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'resource model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsResource:' \
    'RESOURCE_MAX_ENTRIES' \
    'const enum ResourceKind of u8:' \
    'const enum ResourceLeaseState of u8:' \
    'const enum ResourceEvent of u8:' \
    'struct ResourceLease:' \
    'struct ResourceLedger:' \
    'error ResourceContractError:' \
    'def validate_resource_ledger(' \
    'def resource_ledger_acquire(' \
    'def advance_resource_lease('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'OwnerMismatch' \
    'DuplicateId' \
    'InvalidTransition' \
    'AccountingInvalid' \
    'ResourceLimitExceeded' \
    'Abandon'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/resource_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_resource_ledger_contract_prevents_double_close_and_owner_confusion' \
    'ResourceEvent.BeginClose' \
    'ResourceEvent.Abandon' \
    'ResourceContractError.OwnerMismatch' \
    'ResourceContractError.InvalidTransition'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsResource` is the ownership ledger' "$docs"
rg -Fq 'P5 resource-ledger follow-up' "$plan"

printf 'resource model audit: bounded ownership, owner tokens, close/failure edges, and double-close rejection are present\n'
