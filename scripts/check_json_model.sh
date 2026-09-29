#!/usr/bin/env bash

# Compiler-free audit for the namespaced JSON adapter boundary.
set -euo pipefail

MAX_SOURCE_BYTES=16777216
MAX_TOTAL_SOURCE_BYTES=67108864

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if (($# > 1)); then
    printf 'usage: json model audit [repository-root]\n' >&2
    exit 2
fi
repo_root_operand="$script_dir/.."
if (($# == 1)); then
    repo_root_operand="$1"
fi
repo_root="$(CDPATH= cd -- "$repo_root_operand" 2>/dev/null && pwd 2>/dev/null)" || {
    printf 'json model audit: missing repository root\n' >&2
    exit 1
}
model="$repo_root/src/runtime/json_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
encoder="$repo_root/src/runtime/json_encode_model.elisa"
lexer="$repo_root/src/runtime/json_lexer_model.elisa"
parser="$repo_root/src/runtime/json_parse_model.elisa"
json_stream="$repo_root/src/runtime/json_stream_model.elisa"
json_lines_parser="$repo_root/src/runtime/jsonl_parse_model.elisa"
runtime="$repo_root/src/runtime/runtime.elisa"
stream_posix="$repo_root/src/runtime/stream_posix.elisa"
json_lines_file="$repo_root/src/runtime/jsonl_file_posix.elisa"
docs="$repo_root/docs/ir.md"
parity_reference="$repo_root/test/fixtures/script_parity/json_values/reference.py"
parity_candidate="$repo_root/test/fixtures/script_parity/json_values/candidate.elisascript"
parity_expected="$repo_root/test/fixtures/script_parity/json_values/expected.txt"
parity_contract="$repo_root/test/fixtures/script_parity/json_values/CONTRACT.md"
parity_launcher="$repo_root/test/script_parity/json_values_launcher_test.elisascript"
parity_jsonl_input="$repo_root/test/fixtures/script_parity/json_values/records.jsonl"

total_source_bytes=0
for required_file in "$model" "$ir" "$fixture" "$encoder" "$lexer" "$parser" "$json_stream" "$json_lines_parser" "$runtime" "$stream_posix" "$json_lines_file" "$docs" "$parity_reference" "$parity_candidate" "$parity_expected" "$parity_contract" "$parity_launcher" "$parity_jsonl_input"; do
    [[ -f "$required_file" && -r "$required_file" ]] || { printf 'json model audit: missing %s\n' "$required_file" >&2; exit 1; }
    size_output="$(wc -c < "$required_file")"
    source_size="${size_output//[[:space:]]/}"
    [[ "$source_size" =~ ^[0-9]+$ ]] || { printf 'json model audit: unable to inspect %s\n' "$required_file" >&2; exit 1; }
    if (( source_size > MAX_SOURCE_BYTES || source_size > MAX_TOTAL_SOURCE_BYTES - total_source_bytes )); then
        printf 'json model audit: source exceeds audit limit: %s\n' "$required_file" >&2
        exit 2
    fi
    total_source_bytes=$((total_source_bytes + source_size))
done

for lexer_contract in \
    'module EsJsonLex:' \
    'struct JsonLexedSource:' \
    'struct JsonLexeme:' \
    'def lex_json(' \
    'def validate_json_lexed_source(' \
    'def json_lex_scan(' \
    'def json_lex_source_matches_tokens(' \
    'json_number_lexeme_is_valid' \
    'json_lex_read_hex4' \
    'InvalidSurrogate' \
    'UnterminatedComment' \
    'JsonLexError.TokenLimitExceeded' \
    'JsonLexError.DepthLimitExceeded'; do
    rg -Fq "$lexer_contract" "$lexer"
done

for parser_contract in \
    'module EsJsonParse:' \
    'error JsonParseError:' \
    'const enum JsonParsePhase of u8:' \
    'struct JsonParseFrame:' \
    'def json_parse_build(' \
    'def parse_json_document(' \
    'def json_parse_sorted_pending_members(' \
    'document.children.push(child)' \
    'document.members.push(member)' \
    'document.member_key_order.push(member_index)' \
    'document.roots.push(value_index)' \
    'JsonDocumentEvent.Seal' \
    'JsonDocumentEvent.Fail' \
    'JsonParseError.TrailingComma' \
    'JsonParseError.MultipleRoots'; do
    rg -Fq "$parser_contract" "$parser"
done

for json_stream_contract in \
    'module EsJsonStream:' \
    'struct JsonStreamPolicy:' \
    'record_boundary: JsonLineBoundaryMode' \
    'BalancedContainers'; do
    rg -Fq "$json_stream_contract" "$json_stream"
done

for json_lines_parser_contract in \
    'module EsJsonLinesParse:' \
    'def begin_json_lines_reader(' \
    'def next_json_lines_document(' \
    'JsonLinesParseError'; do
    rg -Fq "$json_lines_parser_contract" "$json_lines_parser"
done

for runtime_stream_contract in \
    'module EsRuntime:'; do
    rg -Fq "$runtime_stream_contract" "$runtime"
done

for stream_posix_contract in \
    'struct FileStream:' \
    'def file_stream_open('; do
    rg -Fq "$stream_posix_contract" "$stream_posix"
done

for json_lines_file_contract in \
    'module EsJsonLinesFilePosix:' \
    'def begin_json_lines_file_reader(' \
    'def next_json_lines_file_document(' \
    'def close_json_lines_file_reader(' \
    'JSON_LINES_FILE_CHUNK_BYTES'; do
    rg -Fq "$json_lines_file_contract" "$json_lines_file"
done

for encoder_contract in \
    'module EsJsonEncode:' \
    'error JsonEncodeError:' \
    'def encode_json_root(' \
    'JSON_ENCODE_MAX_OUTPUT_BYTES: usize = DATA_MAX_INPUT_BYTES' \
    'JSON_ENCODE_MAX_FRAMES: usize = 1025' \
    'return false if output.count > limit' \
    'return addition <= limit - output.count' \
    'frames.pop()' \
    'JsonNodeKind.Number' \
    'JsonNodeKind.Object' \
    'if byte == 34u8 or byte == 92u8:' \
    'elif byte < 32u8:' \
    'JsonEncodeError.OutputLimitExceeded'; do
    rg -Fq "$encoder_contract" "$encoder"
done

for declaration in \
    'module EsJson:' \
    'using EsData' \
    'using EsEncoding' \
    'JSON_MODEL_FORMAT_VERSION: u8 = 5' \
    'const enum JsonNodeKind of u8:' \
    'const enum JsonNodeOwnerKind of u8:' \
    'const enum JsonDocumentState of u8:' \
    'const enum JsonDocumentEvent of u8:' \
    'const enum JsonKeyOrder of u8:' \
    'struct JsonRange:' \
    'struct JsonNode:' \
    'struct JsonNodeInput:' \
    'struct JsonArrayChild:' \
    'struct JsonMemberInput:' \
    'struct JsonMember:' \
    'struct JsonDocument:' \
    'member_key_order: darray[usize] = []' \
    'error JsonContractError:' \
    'def validate_json_document(' \
    'def advance_json_document(' \
    'def json_node_child_range_valid(' \
    'def json_stored_keys_order(' \
    'def json_member_key_order_lower_bound(' \
    'def json_number_next_state(' \
    'def json_number_span_valid(' \
    'def json_text_valid(' \
    'def json_text_span_valid(' \
    'def copy_json_scalar(' \
    'document.key_bytes.push(sview_at(member.key, offset))' \
    'document.scalar_data.push(sview_at(node.scalar_value, offset))' \
    'JSON_MAX_TOTAL_KEY_BYTES' \
    'JSON_MAX_TOTAL_SCALAR_BYTES' \
    'sview_len(key) <= field_byte_limit' \
    'member.key_bytes > document.limits.field_bytes' \
    'node.scalar_bytes > document.scalar_data.count - node.scalar_start' \
    'document.scalar_data.count > document.source_bytes - document.key_bytes.count' \
    'json_bounded_add(document.key_bytes.count, sview_len(member.key), document.source_bytes - document.scalar_data.count)' \
    'node.range.end - node.range.start < 2' \
    'member.key_range.end - member.key_range.start < 2' \
    'json_range_valid(member.key_range, document.source_bytes)' \
    'node.kind == JsonNodeKind.Number' \
    'node.kind == JsonNodeKind.Bool' \
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
    'json_stored_keys_order(document.key_bytes, earlier, member)' \
    'json_stored_key_view_order(document, earlier, member.key)' \
    'member.member_key_order_rank != rank' \
    'expected_key_start != document.key_bytes.count' \
    'expected_scalar_start != document.scalar_data.count' \
    'document.key_bytes.count > document.source_bytes' \
    'document.nodes[previous_root].range.end > root.range.start' \
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

if rg -Fq 'advance_json_document(document, JsonDocumentEvent.Append' "$parser"; then
    printf 'json model audit: parser must build one checked batch, not rescan the document per append\n' >&2
    exit 1
fi

rg -Fq 'include "../runtime/json_model.elisa"' "$ir"
rg -Fq 'include "../runtime/json_lexer_model.elisa"' "$ir"
rg -Fq 'include "../runtime/json_parse_model.elisa"' "$ir"
rg -Fq 'include "../runtime/json_encode_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_json_document_contract_is_bounded_and_sealed_explicitly' \
    'member_key_order[0] == 1' \
    'forged_key_index_rejected' \
    'typed_json_document_owns_scalar_values_without_coercing_numbers' \
    'typed_json_lexer_preserves_byte_spans_and_decodes_strings' \
    'copy_json_lexed_string(lexed, 2)' \
    'copy_json_lexed_source_span(lexed, lexed.tokens[8].range)' \
    'bad_surrogate_rejected' \
    'forged_tail_rejected' \
    'forged_string_rejected' \
    'token_limit_rejected' \
    'typed_json_parser_materializes_postorder_and_enforces_grammar' \
    'parse_json_document(lexed)' \
    'sorted_keys: JsonDocument' \
    'trailing_comma_rejected' \
    'duplicate_last' \
    'duplicate_first' \
    'duplicate_rejected' \
    'missing_colon_rejected' \
    'multiple_roots_rejected' \
    'non_string_key_rejected' \
    'missing_value_rejected' \
    'missing_separator_rejected' \
    'typed_json_encoder_is_bounded_and_preserves_values' \
    'encode_json_root(document, 0)' \
    'encoded_values: darray[u8] = encode_json_root(document, 0)' \
    'encoded_object: darray[u8] = encode_json_root(object_document, 0)' \
    'encoded_nested: darray[u8] = encode_json_root(nested_document, 0)' \
    'encoded_empty: darray[u8] = encode_json_root(empty_document, 0)' \
    'encoded_null: darray[u8] = encode_json_root(null_document, 0)' \
    'JsonEncodeError.OutputLimitExceeded' \
    'JsonNodeInput{kind: JsonNodeKind.Number' \
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
    'short_container_rejected' \
    'short_key_rejected' \
    'reversed_key_range_rejected' \
    'number_rejected' \
    'scalar_limit_rejected' \
    'invalid_utf8_key' \
    'copy_json_scalar(document, 3)' \
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

rg -Fq '`EsJson` is the namespaced owned-document boundary' "$docs"

for parity_reference_pattern in \
    'Python JSON/JSONL oracle' \
    'json.loads(SOURCE)' \
    "value['duplicate']" \
    'json.loads(line)' \
    'JSON_LINES_SOURCE.splitlines()' \
    'json.JSONDecodeError' \
    '{"broken": }' \
    'records.jsonl' \
    'file_records = [json.loads(line) for line in source]'; do
    rg -Fq "$parity_reference_pattern" "$parity_reference"
done

for parity_candidate_pattern in \
    'module EsJsonValuesParityCandidate:' \
    'parse_json_document(lexed)' \
    'encode_json_root(document, 0)' \
    'json_values_append_jsonl_memory(output)' \
    'begin_json_lines_reader(Inputs::JSON_LINES_SOURCE)' \
    'next_json_lines_document(reader)' \
    'MALFORMED_JSON_LINES_SOURCE' \
    'json_values_jsonl_malformed_rejected()' \
    'begin_json_lines_file_reader(Inputs::JSON_LINES_PATH)' \
    'next_json_lines_file_document(reader)' \
    'encode_json_root(result.document, 0)' \
    'JsonDuplicateKeyPolicy.KeepLast' \
    'JSON_INDEX_NONE' \
    'blåbær'; do
    rg -Fq "$parity_candidate_pattern" "$parity_candidate"
done

for parity_launcher_pattern in \
    'json_values_and_jsonl_match_python_reference_and_golden' \
    'ELISASCRIPT_VALIDATION_REAUTHORIZED' \
    'ELISASCRIPT_BOUNDED_TEST_RSS_GUARD' \
    'SourceHashes::JSON_PARSER' \
    'SourceHashes::JSON_STREAM' \
    'SourceHashes::JSON_LINES_PARSER' \
    'SourceHashes::RUNTIME' \
    'SourceHashes::STREAM_POSIX' \
    'SourceHashes::JSON_LINES_FILE' \
    'SourceHashes::JSON_LINES_INPUT' \
    'SourceHashes::JSON_ENCODER'; do
    rg -Fq "$parity_launcher_pattern" "$parity_launcher"
done

for parity_expected_pattern in \
    'big=1234567890123456789012345678901234567890' \
    'missing=missing' \
    'nullable=null' \
    'item.2=4' \
    'duplicate=last' \
    'json={"big":1234567890123456789012345678901234567890,' \
    'jsonl={"id":1' \
    'jsonl_file={"id":1' \
    'jsonl_malformed=error'; do
    rg -Fq "$parity_expected_pattern" "$parity_expected"
done

rg -Fq 'compact UTF-8 JSON' "$parity_contract"
rg -Fq 'unterminated final record' "$parity_contract"
rg -Fq 'bounded file-stream' "$parity_contract"
rg -Fq 'required to be rejected' "$parity_contract"
rg -Fq '{"id":3,"payload":null}' "$parity_jsonl_input"
rg -Fq 'not a claim of full Python' "$parity_contract"
rg -Fq '`test/script_parity/json_values_launcher_test.elisascript`' "$docs"

printf 'json model audit: namespaced owned scalar/key arenas, lifecycle contracts, and Python JSON value/JSON Lines parity fixture are present\n'
