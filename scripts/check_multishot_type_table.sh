#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
verifier_file="$repo_root/src/ir/ir_verify.elisa"
type_table_file="$repo_root/src/ir/type_table.elisa"
ir_docs="$repo_root/docs/ir.md"
ledger_file="$repo_root/docs/capabilities/ledger.md"

for file in "$verifier_file" "$type_table_file" "$ir_docs" "$ledger_file"; do
    test -f "$file"
done

if ! rg -q 'def type_table_contains_mutable_aggregate\(type_id: u32, table: TypeTable&' "$verifier_file" || \
   ! rg -q 'return true if row\.kind in \{TypeKind\.Array, TypeKind\.Map\}' "$verifier_file" || \
   ! rg -q 'type_table_contains_mutable_aggregate\(child_id, table, depth \+ 1\)' "$verifier_file" || \
   ! rg -q 'depth >= TYPE_TABLE_MAX_MATCH_DEPTH' "$verifier_file"; then
    printf '%s\n' 'multi-shot TypeTable audit: bounded recursive aggregate walk is incomplete' >&2
    exit 1
fi

if ! rg -q 'type_table_child\(type_id, position\.u16\(\), table\)' "$verifier_file" || \
   ! rg -q 'capture\.type\.descriptor_id != 0 and type_table_contains_mutable_aggregate' "$verifier_file" || \
   ! rg -q 'unknown or malformed child links fail closed' "$ir_docs" || \
   ! rg -q 'interned TypeTable child descriptors' "$ledger_file"; then
    printf '%s\n' 'multi-shot TypeTable audit: descriptor admission/docs are incomplete' >&2
    exit 1
fi

printf '%s\n' 'multi-shot TypeTable audit: nested aggregate capture rejection is bounded and fail-closed'
