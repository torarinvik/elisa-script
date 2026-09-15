#!/bin/sh

# Compiler-free guard for lowerer references to the closed IR type vocabulary.
# This intentionally performs only lexical checks; it never invokes Elisa or a
# generated compiler binary.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
lowerer_file="$repo_root/src/ir/lower_ast.elisa"
ir_model_file="$repo_root/src/ir/ir_model.elisa"
fixture_file="$repo_root/test/ir/elisascript_lowering_test.elisa"

for required_file in "$lowerer_file" "$ir_model_file" "$fixture_file"; do
    if [ ! -f "$required_file" ]; then
        echo "lower AST integrity audit: missing file: $required_file" >&2
        exit 2
    fi
done

# TypeKind is deliberately closed. An absent enum member must not be treated as
# an open/unknown type by the lowerer; the existing empty Named descriptor is
# the explicit contextual-typing sentinel.
if rg -q 'TypeKind\.Unmodeled' "$lowerer_file"; then
    echo "lower AST integrity audit: lowerer references removed TypeKind.Unmodeled" >&2
    exit 1
fi

if ! rg -q '^        const enum TypeKind of u8:' "$ir_model_file"; then
    echo "lower AST integrity audit: closed TypeKind declaration is missing" >&2
    exit 1
fi

contextual_expression='contextual_type_ok: bool = (expected.kind == TypeKind.Named and expected.name == "") or (expected.kind == TypeKind.Int and same_type(literal_type, expected))'
contextual_count=$(rg -F -o "$contextual_expression" "$lowerer_file" | wc -l | tr -d '[:space:]')
if [ "$contextual_count" -ne 2 ]; then
    echo "lower AST integrity audit: expected two contextual integer-literal checks, found $contextual_count" >&2
    exit 1
fi

if ! rg -q '^def lowers_explicit_integer_suffixes_in_contextual_returns\(' "$fixture_file"; then
    echo "lower AST integrity audit: contextual suffixed-integer regression fixture is missing" >&2
    exit 1
fi

echo "lower AST integrity audit: closed TypeKind references and contextual integer literal checks are consistent"
