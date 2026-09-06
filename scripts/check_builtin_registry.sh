#!/usr/bin/env bash

# Compiler-free audit for the first shared typed-builtin registry slice. This
# checks that the registry rows are complete and that semantic/lowering code
# consumes the same metadata for every registered spelling.

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
registry_file="$repo_root/vendor/elisa-compiler/src/semantic/builtin_registry.elisa"
semantic_file="$repo_root/vendor/elisa-compiler/src/semantic/symbols.elisa"
receiver_semantic_file="$repo_root/vendor/elisa-compiler/src/semantic/check_ufcs_unknown_method.elisa"
inference_file="$repo_root/vendor/elisa-compiler/src/semantic/resolve_types_infer.elisa"
lowerer_file="$repo_root/src/ir/lower_ast.elisa"
opcode_file="$repo_root/src/ir/ir_model.elisa"
verifier_file="$repo_root/src/ir/ir_verify.elisa"

for required_file in "$registry_file" "$semantic_file" "$receiver_semantic_file" "$inference_file" "$lowerer_file" "$opcode_file" "$verifier_file"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'builtin registry audit: missing file: %s\n' "$required_file" >&2
        exit 2
    fi
done

registry_names="$(sed -n '/def typed_builtin_names/,/^        def /p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
method_names="$(sed -n '/def typed_builtin_method_names/,/^        def typed_builtin_regex_method_names/p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
regex_method_names="$(sed -n '/def typed_builtin_regex_method_names/,$p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
if [[ -z "$registry_names" ]]; then
    printf 'builtin registry audit: typed_builtin_names is empty\n' >&2
    exit 1
fi
if [[ -z "$method_names" ]]; then
    printf 'builtin registry audit: typed_builtin_method_names is empty\n' >&2
    exit 1
fi
if [[ -z "$regex_method_names" ]]; then
    printf 'builtin registry audit: typed_builtin_regex_method_names is empty\n' >&2
    exit 1
fi

for name in $registry_names; do
    if ! rg -q "name == \"$name\"" "$registry_file"; then
        printf 'builtin registry audit: %s has no typed spec row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "callee_name == \"$name\"" "$lowerer_file"; then
        printf 'builtin registry audit: lowerer has no dispatch branch for %s\n' "$name" >&2
        exit 1
    fi
    if rg -q "add_symbol\(\"$name\"" "$semantic_file"; then
        printf 'builtin registry audit: %s is re-seeded outside the typed registry loop\n' "$name" >&2
        exit 1
    fi
    opcode="$(sed -n "s/.*name: \"$name\".*opcode: \"\([A-Za-z0-9_]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$opcode" ]] || ! rg -q "^[[:space:]]*$opcode$" "$opcode_file"; then
        printf 'builtin registry audit: %s has no declared IR opcode (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
    if [[ -z "$opcode" ]] || ! rg -q "Opcode\\.$opcode" "$verifier_file"; then
        printf 'builtin registry audit: %s opcode is not verifier-covered (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
    argument_types="$(sed -n "s/.*name: \"$name\".*argument_types: \"\([^\"]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$argument_types" ]]; then
        printf 'builtin registry audit: %s has no argument-type descriptor\n' "$name" >&2
        exit 1
    fi
done

if ! rg -q 'typed_builtin_method_spec\("Text", method_name\)' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no receiver-method registry consumer\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Regex", method_name\)' "$lowerer_file" || \
   ! rg -q 'scripting_regex_builtin_available\(state, method_name\)' "$lowerer_file" || \
   ! rg -q 'is_regex_receiver_expression\(receiver_expression, state\)' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no Regex receiver registry consumer\n' >&2
    exit 1
fi
if ! rg -q 'scripting_text_builtin_available\(state, method_name\)' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer does not guard Text dispatch against source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'scripting_regex_builtin_available\(state, method_name\)' "$lowerer_file" || \
   ! rg -q 'scripting_regex_method_available\(table, method_name\)' "$inference_file"; then
    printf 'builtin registry audit: regex receiver dispatch/inference does not guard source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'lowered_function_index\(state, qualified_name\) == state\.function_names\.count' "$lowerer_file"; then
    printf 'builtin registry audit: qualified builtin dispatch does not guard source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_call_shape\("Text", method_name' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no receiver-method shape consumer\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Text", method\)\.known' "$receiver_semantic_file"; then
    printf 'builtin registry audit: semantic receiver admission does not consume the Text registry\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Regex", method\)\.known' "$receiver_semantic_file" || \
   ! rg -q 'ufm_check_regex_builtin_arity' "$receiver_semantic_file" || \
   ! rg -q 'ufm_check_regex_builtin_argument_types' "$receiver_semantic_file"; then
    printf 'builtin registry audit: semantic Regex receiver checking does not consume the registry\n' >&2
    exit 1
fi
if ! rg -q 'ufm_has_source_function\(table, method\)' "$receiver_semantic_file"; then
    printf 'builtin registry audit: semantic Text diagnostics do not guard source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'symbol\.line != 0' "$receiver_semantic_file" || \
   ! rg -q 'symbol\.line != 0' "$inference_file"; then
    printf 'builtin registry audit: source-shadowing guards do not exclude line-zero builtin seeds\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Text", method\)' "$inference_file"; then
    printf 'builtin registry audit: semantic receiver inference does not consume the Text registry\n' >&2
    exit 1
fi
if ! rg -q 'scripting_text_method_available\(table, method_name\)' "$inference_file"; then
    printf 'builtin registry audit: semantic receiver inference does not guard source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Regex", method\)' "$inference_file" || \
   ! rg -q 'scripting_regex_method_available\(table, method_name\)' "$inference_file"; then
    printf 'builtin registry audit: semantic Regex receiver inference does not consume the registry\n' >&2
    exit 1
fi
if ! rg -q 'argument_names: sview' "$registry_file" || \
   ! rg -q 'named_argument_index: u32' "$registry_file" || \
   ! rg -q 'builtin_named_argument_allowed' "$lowerer_file" || \
   ! rg -q 'named_argument_index' "$lowerer_file" || \
   ! rg -q 'ufm_text_named_argument_allowed' "$receiver_semantic_file" || \
   ! rg -q 'named_argument_index' "$receiver_semantic_file"; then
    printf 'builtin registry audit: named-argument metadata is not shared across registry, semantic, and lowerer layers\n' >&2
    exit 1
fi
if ! rg -q 'ufm_check_text_builtin_arity' "$receiver_semantic_file" || \
   ! rg -q 'spec\.arity_min' "$receiver_semantic_file" || \
   ! rg -q 'DiagnosticKind\.ArityMismatch' "$receiver_semantic_file" || \
   ! rg -q 'DiagnosticKind\.CallArgumentError' "$receiver_semantic_file" || \
   ! rg -q '"no_names"' "$receiver_semantic_file"; then
    printf 'builtin registry audit: semantic receiver arity/named-argument checking does not consume registry ranges\n' >&2
    exit 1
fi
if ! rg -q 'ufm_check_global_builtin_arity' "$receiver_semantic_file" || \
   ! rg -q 'ufm_check_global_builtin_argument_types' "$receiver_semantic_file" || \
   ! rg -q 'ufm_global_argument_expected' "$receiver_semantic_file" || \
   ! rg -q 'not ufm_has_source_function' "$receiver_semantic_file"; then
    printf 'builtin registry audit: global registry rows are not semantically checked with source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'darray\[text\],text' "$registry_file" || \
   ! rg -q 'ufm_text_array_argument_is_text\(expression, var_types, type_names, table\)' "$receiver_semantic_file"; then
    printf 'builtin registry audit: global structural text-array descriptors are not checked through the type table\n' >&2
    exit 1
fi
if ! rg -q 'ufm_check_text_builtin_argument_types' "$receiver_semantic_file" || \
   ! rg -q 'spec\.argument_types' "$receiver_semantic_file" || \
   ! rg -q 'DiagnosticKind\.LiteralArgTypeMismatch' "$receiver_semantic_file" || \
   ! rg -q 'DiagnosticKind\.FirmArgTypeMismatch' "$receiver_semantic_file"; then
    printf 'builtin registry audit: semantic receiver argument checking does not consume registry types\n' >&2
    exit 1
fi
if ! rg -q 'darray\[text\]' "$receiver_semantic_file" || \
   ! rg -q 'structural_type_id_of' "$receiver_semantic_file" || \
   ! rg -q 'interned_elem\(' "$receiver_semantic_file"; then
    printf 'builtin registry audit: structural Text argument descriptors are not checked through the type table\n' >&2
    exit 1
fi
if ! rg -q 'text_method_spec: EsBuiltin::BuiltinSpec' "$inference_file" 2>/dev/null && \
   ! rg -q 'text_method_spec: EsBuiltin::BuiltinSpec' "$repo_root/vendor/elisa-compiler/src/semantic/resolve_types.elisa"; then
    printf 'builtin registry audit: structural Text result inference does not consume receiver registry rows\n' >&2
    exit 1
fi
if ! rg -q 'regex_method_spec: EsBuiltin::BuiltinSpec' "$repo_root/vendor/elisa-compiler/src/semantic/resolve_types.elisa"; then
    printf 'builtin registry audit: structural Regex result inference does not consume receiver registry rows\n' >&2
    exit 1
fi
if ! rg -q 'global_registry_spec: EsBuiltin::BuiltinSpec' "$repo_root/vendor/elisa-compiler/src/semantic/resolve_types.elisa"; then
    printf 'builtin registry audit: structural global result inference does not consume registry rows\n' >&2
    exit 1
fi
if ! rg -q 'def record_builtin_contract' "$lowerer_file" || \
   ! rg -q 'record_builtin_contract\(registry_spec, state\)' "$lowerer_file" || \
   ! rg -q 'record_builtin_contract\(method_spec, state\)' "$lowerer_file" || \
   ! rg -q 'state\.required_effects\.push\(spec\.effects\)' "$lowerer_file" || \
   ! rg -q 'state\.required_errors\.push\(spec\.errors\)' "$lowerer_file"; then
    printf 'builtin registry audit: declared effect/error rows are not centrally recorded by lowering\n' >&2
    exit 1
fi
if ! rg -q 'error_name in lowered\.module\.functions\[0\]\.errors where error_name == "ParseError"' "$repo_root/test/ir/elisascript_lowering_test.elisa" || \
   ! rg -q 'has_text\(lowered\.module\.functions\[0\]\.errors, "IndexOutOfBounds"\)' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: fallible registry rows lack lowering fixtures\n' >&2
    exit 1
fi

for name in $method_names; do
    if ! rg -q "known: true, name: \"$name\", receiver: \"Text\"" "$registry_file"; then
        printf 'builtin registry audit: Text.%s has no receiver-specific registry row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "method_name == \"$name\"" "$lowerer_file"; then
        printf 'builtin registry audit: lowerer has no Text method branch for %s\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "name: \"$name\", receiver: \"Text\".*argument_types:" "$registry_file"; then
        printf 'builtin registry audit: Text.%s has no argument-type descriptor\n' "$name" >&2
        exit 1
    fi
    opcode="$(sed -n "s/.*name: \"$name\".*receiver: \"Text\".*opcode: \"\([A-Za-z0-9_]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$opcode" ]] || ! rg -q "Opcode\\.$opcode" "$verifier_file"; then
        printf 'builtin registry audit: Text.%s opcode is not verifier-covered (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
done

for name in $regex_method_names; do
    if ! rg -q "known: true, name: \"$name\", receiver: \"Regex\"" "$registry_file"; then
        printf 'builtin registry audit: Regex.%s has no receiver-specific registry row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "method_name == \"$name\"" "$lowerer_file"; then
        printf 'builtin registry audit: lowerer has no Regex method branch for %s\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "name: \"$name\", receiver: \"Regex\".*argument_types:" "$registry_file"; then
        printf 'builtin registry audit: Regex.%s has no argument-type descriptor\n' "$name" >&2
        exit 1
    fi
    opcode="$(sed -n "s/.*name: \"$name\".*receiver: \"Regex\".*opcode: \"\([A-Za-z0-9_]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$opcode" ]] || ! rg -q "Opcode\\.$opcode" "$verifier_file"; then
        printf 'builtin registry audit: Regex.%s opcode is not verifier-covered (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
done

if ! rg -q 'typed_builtin_spec\(builtin_name\)' "$semantic_file"; then
    printf 'builtin registry audit: semantic seed table does not consume typed_builtin_spec\n' >&2
    exit 1
fi

if ! rg -q 'argument_types: builtin_spec\.argument_types' "$semantic_file" || \
   ! rg -q 'effects: builtin_spec\.effects' "$semantic_file" || \
   ! rg -q 'errors: builtin_spec\.errors' "$semantic_file" || \
   ! rg -q 'opcode: builtin_spec\.opcode' "$semantic_file"; then
    printf 'builtin registry audit: semantic symbols do not preserve full builtin metadata\n' >&2
    exit 1
fi

# The strict scalar/text rows must source their result types from the registry;
# this prevents a lowerer branch from silently drifting from semantic metadata.
if ! rg -q "typed_builtin_spec\(callee_name\)\.return_type" "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no registry return-type consumer\n' >&2
    exit 1
fi

if ! rg -q 'state\.required_errors\.push\(spec\.errors\)' "$lowerer_file" || \
   ! rg -q 'record_builtin_contract\(registry_spec, state\)' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no registry error-row consumer\n' >&2
    exit 1
fi
if ! rg -q 'trim_mode: i64 = 1 if callee_name == "lstrip"' "$lowerer_file" || \
   ! rg -q 'callee_name == "rstrip" else 0' "$lowerer_file"; then
    printf 'builtin registry audit: global trim aliases do not preserve left/right mode metadata\n' >&2
    exit 1
fi
if ! rg -q 'def typed_builtin_result_type' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(EsBuiltin::typed_builtin_spec\(callee_name\)\)' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: aggregate registry rows do not share lowerer result-shape conversion\n' >&2
    exit 1
fi

if ! rg -q 'scripting_registry_direct_return_type' "$inference_file" || \
   ! rg -q 'registry_return: InferType' "$inference_file"; then
    printf 'builtin registry audit: direct-call inference has no registry return-type adapter\n' >&2
    exit 1
fi
if ! rg -q 'name == "regex"' "$inference_file" || \
   ! rg -q 'name: "Regex"' "$inference_file"; then
    printf 'builtin registry audit: regex typed-literal inference is not nominally preserved\n' >&2
    exit 1
fi

printf 'builtin registry audit: %s global, %s Text, and %s Regex receiver spellings share semantic and lowerer metadata\n' "$(printf '%s\n' "$registry_names" | awk 'NF {count += 1} END {print count + 0}')" "$(printf '%s\n' "$method_names" | awk 'NF {count += 1} END {print count + 0}')" "$(printf '%s\n' "$regex_method_names" | awk 'NF {count += 1} END {print count + 0}')"
