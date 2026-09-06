#!/usr/bin/env bash

# Compiler-free audit for the source-declared effect-operation metadata bridge.
# The parser intentionally keeps effect declarations in a side table while the
# typed resolver is being completed. This guard makes sure the type syntax is
# not accidentally dropped between parser capture and semantic lookup.

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
tokens_file="$repo_root/vendor/elisa-compiler/src/parser/parser_tokens.elisa"
parser_file="$repo_root/vendor/elisa-compiler/src/parser/parser_decl_effect.elisa"
capture_file="$repo_root/vendor/elisa-compiler/src/parser/parser_decl_impl.elisa"
semantic_file="$repo_root/vendor/elisa-compiler/src/semantic/check_signal_effect.elisa"
docs_file="$repo_root/docs/semantics.md"
lowerer_file="$repo_root/src/ir/lower_ast.elisa"
ir_model_file="$repo_root/src/ir/ir_model.elisa"
ir_verify_file="$repo_root/src/ir/ir_verify.elisa"
fixture_file="$repo_root/test/ir/elisascript_lowering_test.elisa"
runtime_file="$repo_root/src/ir/interpret.elisa"
serialize_file="$repo_root/src/ir/serialize.elisa"

for required_file in "$tokens_file" "$parser_file" "$capture_file" "$semantic_file" "$docs_file" "$lowerer_file" "$ir_model_file" "$ir_verify_file" "$fixture_file" "$runtime_file" "$serialize_file"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'effect operation metadata audit: missing file: %s\n' "$required_file" >&2
        exit 2
    fi
done

effect_struct="$(sed -n '/struct EffectOperation:/,/^    struct /p' "$tokens_file")"
for field in arity payload_signature result_signature operation_id; do
    if ! printf '%s\n' "$effect_struct" | rg -q "^[[:space:]]+$field:"; then
        printf 'effect operation metadata audit: EffectOperation omits %s\n' "$field" >&2
        exit 1
    fi
done

for helper in effect_operation_payload_signature effect_operation_result_signature; do
    if ! rg -q "def $helper\(" "$parser_file"; then
        printf 'effect operation metadata audit: parser omits %s\n' "$helper" >&2
        exit 1
    fi
done

constructor="$(rg 'Ast::EffectOperation\{' "$capture_file")"
for field in payload_signature result_signature operation_id; do
    if ! printf '%s\n' "$constructor" | rg -q "$field:"; then
        printf 'effect operation metadata audit: capture constructor omits %s\n' "$field" >&2
        exit 1
    fi
done

sig_struct="$(sed -n '/struct SigEffectOperation:/,/^        #/p' "$semantic_file")"
for field in payload_signature result_signature operation_id; do
    if ! printf '%s\n' "$sig_struct" | rg -q "^[[:space:]]+$field:"; then
        printf 'effect operation metadata audit: semantic lookup omits %s\n' "$field" >&2
        exit 1
    fi
done

for field in payload_signature result_signature operation_id; do
    if ! rg -q "candidate\.$field" "$semantic_file"; then
        printf 'effect operation metadata audit: semantic lookup does not carry candidate.%s\n' "$field" >&2
        exit 1
    fi
done
if ! rg -q 'def effect_operation_identity\(' "$tokens_file" || ! rg -q 'operation_id: Ast::effect_operation_identity' "$capture_file"; then
    printf 'effect operation metadata audit: parser does not assign the stable operation identity\n' >&2
    exit 1
fi
if ! rg -q 'operation_id: u64 = 0' "$ir_model_file" || ! rg -q 'def effect_operation_identity\(' "$ir_model_file"; then
    printf 'effect operation metadata audit: IR operation identity fields/helper are missing\n' >&2
    exit 1
fi
if ! rg -q 'resumption_id: u64 = 0' "$ir_model_file" || ! rg -q 'resumption_id: Ast::effect_operation_identity\("Resume"' "$lowerer_file"; then
    printf 'effect operation metadata audit: IR/lowering resumption identity fields are missing\n' >&2
    exit 1
fi
if ! rg -q 'operation_identity_matches\(' "$ir_verify_file" || ! rg -q 'handler clause operation id does not match' "$ir_verify_file"; then
    printf 'effect operation metadata audit: verifier does not validate populated operation identities\n' >&2
    exit 1
fi
if ! rg -q 'operation_id == Ast::effect_operation_identity' "$fixture_file" || ! rg -q 'handler clause operation id does not match' "$fixture_file"; then
    printf 'effect operation metadata audit: lowering fixtures omit operation identity coverage\n' >&2
    exit 1
fi
if ! rg -q 'resume id does not match its handler symbol' "$ir_verify_file" || ! rg -q 'resumption_id == Ast::effect_operation_identity\("Resume"' "$fixture_file"; then
    printf 'effect operation metadata audit: verifier/fixture resumption identity coverage is missing\n' >&2
    exit 1
fi
if ! rg -q 'failure_operation_id: mutable u64 = 0' "$runtime_file" || ! rg -q 'operation_id: u64 = 0' "$runtime_file"; then
    printf 'effect operation metadata audit: runtime failure/guard ids are missing\n' >&2
    exit 1
fi
if ! rg -q 'resumption_id: u64 = 0' "$runtime_file" || ! rg -q 'continuation\.resumption_id' "$runtime_file"; then
    printf 'effect operation metadata audit: runtime continuation identity matching is missing\n' >&2
    exit 1
fi
for serialized_id in 'value.operation_id' 'value.resumption_id'; do
    if ! rg -q "canonical_emit_u64\(output, $serialized_id\)" "$serialize_file" || ! rg -q "canonical_hash_u64\(result, $serialized_id\)" "$serialize_file"; then
        printf 'effect operation metadata audit: canonical serialization omits %s\n' "$serialized_id" >&2
        exit 1
    fi
done
if ! rg -q 'def runtime_operation_matches\(' "$runtime_file" || ! rg -q 'runtime_handler_covers_operation\([^)]*instruction\.operation_id' "$runtime_file"; then
    printf 'effect operation metadata audit: runtime handler dispatch does not consume operation identities\n' >&2
    exit 1
fi
if ! rg -q 'DiagnosticKind.TypeMismatch.*expected: "void".*operation_info\.result_signature' "$semantic_file"; then
    printf 'effect operation metadata audit: semantic signal checking does not reject non-void declarations\n' >&2
    exit 1
fi

for helper in effect_operation_bare_result_spelling effect_operation_trim_type_spelling effect_operation_top_level_comma effect_operation_type_from_spelling effect_operation_result_type effect_operation_result_is_known effect_operation_declared effect_operation_declared_arity effect_operation_parameter_type effect_operation_payload_type effect_operation_single_payload_type effect_operation_payload_is_known; do
    if ! rg -q "def $helper\(" "$lowerer_file"; then
        printf 'effect operation metadata audit: lowerer omits %s\n' "$helper" >&2
        exit 1
    fi
done
if ! rg -q 'def source_handler_operation_conforms\(' "$lowerer_file"; then
    printf 'effect operation metadata audit: source handler conformance helper is missing\n' >&2
    exit 1
fi
if ! rg -q 'def source_handler_add_callback_contract' "$lowerer_file"; then
    printf 'effect operation metadata audit: source handler callback contract propagation helper is missing\n' >&2
    exit 1
fi
for callback_contract in 'handler.introduces_effects <- updated_effects' 'handler.errors <- updated_errors' 'source_handler_add_callback_contract\(file, function_line, effects, handler\)'; do
    if ! rg -q "$callback_contract" "$lowerer_file"; then
        printf 'effect operation metadata audit: source handler callback contract omits %s\n' "$callback_contract" >&2
        exit 1
    fi
done
for conformance in 'callback parameter count does not match the declared effect operation' 'callback parameter type does not match the declared effect operation payload' 'callback result type does not match the declared effect operation result'; do
    if ! rg -q "$conformance" "$lowerer_file"; then
        printf 'effect operation metadata audit: source handler conformance omits %s\n' "$conformance" >&2
        exit 1
    fi
done
if ! rg -q 'effect_operation_result_type\(state\.source_file, family, operation\)' "$lowerer_file"; then
    printf 'effect operation metadata audit: perform lowering does not consult declared result metadata\n' >&2
    exit 1
fi
if ! rg -q 'effect_operation_payload_type\(state\.source_file, family, operation, argument_index - 1\)' "$lowerer_file"; then
    printf 'effect operation metadata audit: perform lowering does not consult each declared payload type\n' >&2
    exit 1
fi
if ! rg -q 'effect_operation_payload_type\(state\.source_file, effect_family\(reference\), effect_operation\(reference\), payload_index\)' "$lowerer_file"; then
    printf 'effect operation metadata audit: signal lowering does not consult each declared payload type\n' >&2
    exit 1
fi
for spelling in 'array_ir_type(element)' 'set_ir_type(element)' 'map_ir_type(key, value)' 'effect_operation_top_level_comma(inner)'; do
    if ! rg -Fq "$spelling" "$lowerer_file"; then
        printf 'effect operation metadata audit: structural type spelling support omits %s\n' "$spelling" >&2
        exit 1
    fi
done
if rg -q 'at most one positional payload' "$lowerer_file"; then
    printf 'effect operation metadata audit: lowerer still caps perform at one payload\n' >&2
    exit 1
fi
for shape in 'payloads.count.u16()' 'payload_index in 0..<operand_types.count'; do
    if ! rg -Fq "$shape" "$lowerer_file"; then
        printf 'effect operation metadata audit: ordered multi-payload lowering omits %s\n' "$shape" >&2
        exit 1
    fi
done
if ! rg -q 'effect_operation_declared\(state\.source_file, family, operation\)' "$lowerer_file"; then
    printf 'effect operation metadata audit: perform lowering does not enforce source operation arity\n' >&2
    exit 1
fi
if ! rg -q 'effect_operation_declared\(state\.source_file, effect_family\(reference\), effect_operation\(reference\)\)' "$lowerer_file"; then
    printf 'effect operation metadata audit: signal lowering does not enforce source operation arity\n' >&2
    exit 1
fi
for message in 'perform payload arity does not match the declared effect operation' 'signal payload arity does not match the declared effect operation'; do
    if ! rg -q "$message" "$lowerer_file"; then
        printf 'effect operation metadata audit: lowerer omits arity diagnostic: %s\n' "$message" >&2
        exit 1
    fi
done
if ! rg -q 'signal requires a void declared effect operation result' "$lowerer_file"; then
    printf 'effect operation metadata audit: signal lowering does not reject non-void declarations\n' >&2
    exit 1
fi

if ! rg -q 'exact source spans for the parenthesized payload list and result type|payload_signature|result_signature' "$docs_file"; then
    printf 'effect operation metadata audit: semantics documentation omits preserved signature spans\n' >&2
    exit 1
fi

printf 'effect operation metadata audit: typed declaration spans preserved through parser and semantic lookup\n'
