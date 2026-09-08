#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
registry_file="$repo_root/vendor/elisa-compiler/src/semantic/builtin_registry.elisa"
semantic_types_file="$repo_root/vendor/elisa-compiler/src/semantic/semantic_types.elisa"
symbols_file="$repo_root/vendor/elisa-compiler/src/semantic/symbols.elisa"
lowerer_file="$repo_root/src/ir/lower_ast.elisa"
verifier_file="$repo_root/src/ir/ir_verify.elisa"
semantics_file="$repo_root/docs/semantics.md"
ledger_file="$repo_root/docs/capabilities/ledger.md"

for file in "$registry_file" "$semantic_types_file" "$symbols_file" "$lowerer_file" "$verifier_file" "$semantics_file" "$ledger_file"; do
    test -f "$file"
done

if ! rg -q 'effects_secondary: sview = ""' "$registry_file" || \
   ! rg -q 'def builtin_effect_at\(spec: BuiltinSpec, index: u32\)' "$registry_file" || \
   ! rg -q 'return spec\.effects if index == 0 else spec\.effects_secondary if index == 1' "$registry_file"; then
    printf '%s\n' 'builtin effect metadata audit: registry effect-slot accessor is incomplete' >&2
    exit 1
fi

for copy_name in copy_path cp copyfile copy_tree copytree; do
    if ! rg -q "name: \"$copy_name\".*effects: \"File.Read\", effects_secondary: \"File.Write\"" "$registry_file"; then
        printf 'builtin effect metadata audit: copy row lacks independent read/write slots for %s\n' "$copy_name" >&2
        exit 1
    fi
done

if ! rg -q 'effects_secondary: sview = sview\("", 0, 0\)' "$semantic_types_file" || \
   ! rg -q 'effects_secondary: builtin_spec\.effects_secondary' "$symbols_file"; then
    printf '%s\n' 'builtin effect metadata audit: seeded semantic symbols do not preserve secondary effects' >&2
    exit 1
fi

if ! rg -q 'primary_effect: sview = EsBuiltin::builtin_effect_at\(spec, 0\)' "$lowerer_file" || \
   ! rg -q 'secondary_effect: sview = EsBuiltin::builtin_effect_at\(spec, 1\)' "$lowerer_file" || \
   ! rg -q 'state\.required_effects\.push\(secondary_effect\)' "$lowerer_file"; then
    printf '%s\n' 'builtin effect metadata audit: lowerer does not consume indexed effect slots' >&2
    exit 1
fi

if ! rg -q 'path copy requires File\.Read in the function effect row' "$verifier_file" || \
   ! rg -q 'path copy or move requires File\.Write in the function effect row' "$verifier_file" || \
   ! rg -q 'tree copy requires File\.Read in the function effect row' "$verifier_file" || \
   ! rg -q 'tree copy requires File\.Write in the function effect row' "$verifier_file"; then
    printf '%s\n' 'builtin effect metadata audit: verifier does not require both copy permissions' >&2
    exit 1
fi

if ! rg -q 'can\[File\.Read, File\.Write\]' "$semantics_file" || \
   ! rg -q 'secondary effect' "$semantics_file" || \
   ! rg -q 'independent read/write' "$ledger_file"; then
    printf '%s\n' 'builtin effect metadata audit: copy effect contract is not documented' >&2
    exit 1
fi

printf '%s\n' 'builtin effect metadata audit: registry, semantic seeds, lowerer, verifier, and docs preserve independent copy read/write effects'
