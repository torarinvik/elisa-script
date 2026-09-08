#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
verifier_file="$repo_root/src/ir/ir_verify.elisa"
type_table_file="$repo_root/src/ir/type_table.elisa"
ir_docs="$repo_root/docs/ir.md"
ledger_file="$repo_root/docs/capabilities/ledger.md"
ir_test_file="$repo_root/test/ir/elisascript_ir_test.elisa"

for file in "$verifier_file" "$type_table_file" "$ir_docs" "$ledger_file" "$ir_test_file"; do
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
   ! rg -q 'interned TypeTable child descriptors' "$ledger_file" || \
   ! rg -q 'multi_shot_rejects_nested_aggregate_in_malformed_type_descriptor' "$ir_test_file" || \
   ! rg -q 'IssueKind\.UnsafeMultiShot\) == 1' "$ir_test_file" || \
   ! rg -q 'return 0 if not type_kind_valid\(kind\) or not type_descriptor_child_arity_valid' "$type_table_file" || \
   ! rg -q 'return 0 if child_id == 0 or child_id\.usize\(\) > table\.rows\.count' "$type_table_file" || \
   ! rg -q 'invalid_forward_child' "$ir_test_file"; then
    printf '%s\n' 'multi-shot TypeTable audit: descriptor admission/docs are incomplete' >&2
    exit 1
fi

printf '%s\n' 'multi-shot TypeTable audit: nested aggregate capture rejection is bounded and fail-closed'
