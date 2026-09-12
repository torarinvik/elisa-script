#!/usr/bin/env bash

# Compiler-free audit for the namespaced JSON adapter boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/json_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'json model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsJson:' \
    'using EsData' \
    'JSON_MODEL_FORMAT_VERSION' \
    'const enum JsonNodeKind of u8:' \
    'const enum JsonNodeOwnerKind of u8:' \
    'const enum JsonDocumentState of u8:' \
    'const enum JsonDocumentEvent of u8:' \
    'struct JsonRange:' \
    'struct JsonNode:' \
    'struct JsonArrayChild:' \
    'struct JsonMemberInput:' \
    'struct JsonMember:' \
    'struct JsonDocument:' \
    'error JsonContractError:' \
    'def validate_json_document(' \
    'def advance_json_document(' \
    'def json_node_child_range_valid(' \
    'def json_stored_key_equals_view(' \
    'def json_stored_keys_equal(' \
    'document.key_bytes.push(sview_at(member.key, offset).u8())' \
    'JSON_MAX_TOTAL_KEY_BYTES' \
    'sview_len(key) <= field_byte_limit' \
    'member.key_bytes > document.limits.field_bytes' \
    'try validate_json_document(document)'; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'InvalidRange' \
    'InvalidChildRange' \
    'json_node_child_range_valid(node, document.children.count)' \
    'json_node_member_range_valid(node, document.members.count)' \
    'edge.owner_index != index' \
    'member.owner_index != index' \
    'value.owner_kind != JsonNodeOwnerKind.ArrayChild' \
    'value.owner_kind != JsonNodeOwnerKind.ObjectMember' \
    'node.owner_kind == JsonNodeOwnerKind.Detached' \
    'node.owner_kind == JsonNodeOwnerKind.Root' \
    'old_value.owner_kind <- JsonNodeOwnerKind.Detached' \
    'root.owner_kind <- JsonNodeOwnerKind.Root' \
    'previous_value.range.end > value.range.start' \
    'member.key_range.end > value.range.start' \
    'member.key_bytes > member.key_range.end - member.key_range.start' \
    'previous_member.key_range.end > member.key_range.start' \
    'json_stored_keys_equal(document.key_bytes, earlier, member)' \
    'json_stored_key_equals_view(document, earlier, member.key)' \
    'expected_key_start != document.key_bytes.count' \
    'document.policy.duplicate_keys == JsonDuplicateKeyPolicy.KeepFirst' \
    'node.scalar_bytes > node.range.end - node.range.start' \
    'if node.kind == JsonNodeKind.Array' \
    'document.state == JsonDocumentState.Empty' \
    'document.state == JsonDocumentState.Sealed' \
    'derived_depth' \
    'DuplicateObjectKey' \
    'NodeLimitExceeded' \
    'InvalidArrayChild' \
    'InvalidMemberOwner' \
    'InvalidMemberOrder' \
    'MemberLimitExceeded' \
    'RootLimitExceeded' \
    'AppendNotReady' \
    'SealNotReady'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/json_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_json_document_contract_is_bounded_and_sealed_explicitly' \
    'JsonDocumentEvent.AppendNode' \
    'JsonDocumentEvent.AppendArrayChild' \
    'JsonDocumentEvent.AppendMember' \
    'JsonNodeOwnerKind.ObjectMember' \
    'JsonNodeOwnerKind.Detached' \
    'JsonContractError.DuplicateObjectKey' \
    'duplicate_root_rejected' \
    'unordered_child_rejected' \
    'late_key_rejected' \
    'key_limit_rejected' \
    'nul_key.key_bytes[2] == 0' \
    'JsonArrayChild{owner_index: 1, value_index: 0, ordinal: 0}' \
    'JsonMemberInput{owner_index: 3, key: "name"' \
    'key_bytes: [110, 97, 109, 101, 110, 97, 109, 101]' \
    'nul_key' \
    'forged_policy_duplicates' \
    'forged_empty' \
    'forged_depth'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsJson` is the namespaced adapter boundary' "$docs"
rg -Fq 'Latest P08 JSON adapter follow-up' "$plan"

printf 'json model audit: namespaced bounded node-table and document lifecycle contracts are present\n'
