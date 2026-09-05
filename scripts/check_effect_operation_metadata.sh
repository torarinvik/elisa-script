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

for required_file in "$tokens_file" "$parser_file" "$capture_file" "$semantic_file" "$docs_file" "$lowerer_file"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'effect operation metadata audit: missing file: %s\n' "$required_file" >&2
        exit 2
    fi
done

effect_struct="$(sed -n '/struct EffectOperation:/,/^    struct /p' "$tokens_file")"
for field in arity payload_signature result_signature; do
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
for field in payload_signature result_signature; do
    if ! printf '%s\n' "$constructor" | rg -q "$field:"; then
        printf 'effect operation metadata audit: capture constructor omits %s\n' "$field" >&2
        exit 1
    fi
done

sig_struct="$(sed -n '/struct SigEffectOperation:/,/^        #/p' "$semantic_file")"
for field in payload_signature result_signature; do
    if ! printf '%s\n' "$sig_struct" | rg -q "^[[:space:]]+$field:"; then
        printf 'effect operation metadata audit: semantic lookup omits %s\n' "$field" >&2
        exit 1
    fi
done

for field in payload_signature result_signature; do
    if ! rg -q "candidate\.$field" "$semantic_file"; then
        printf 'effect operation metadata audit: semantic lookup does not carry candidate.%s\n' "$field" >&2
        exit 1
    fi
done

for helper in effect_operation_bare_result_spelling effect_operation_result_type effect_operation_result_is_known effect_operation_single_payload_type effect_operation_payload_is_known; do
    if ! rg -q "def $helper\(" "$lowerer_file"; then
        printf 'effect operation metadata audit: lowerer omits %s\n' "$helper" >&2
        exit 1
    fi
done
if ! rg -q 'effect_operation_result_type\(state\.source_file, family, operation\)' "$lowerer_file"; then
    printf 'effect operation metadata audit: perform lowering does not consult declared result metadata\n' >&2
    exit 1
fi
if ! rg -q 'effect_operation_single_payload_type\(state\.source_file, family, operation\)' "$lowerer_file"; then
    printf 'effect operation metadata audit: perform lowering does not consult declared payload metadata\n' >&2
    exit 1
fi

if ! rg -q 'exact source spans for the parenthesized payload list and result type|payload_signature|result_signature' "$docs_file"; then
    printf 'effect operation metadata audit: semantics documentation omits preserved signature spans\n' >&2
    exit 1
fi

printf 'effect operation metadata audit: typed declaration spans preserved through parser and semantic lookup\n'
