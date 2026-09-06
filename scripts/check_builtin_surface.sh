#!/usr/bin/env bash

# Compiler-free builtin-surface audit. The semantic seed table and the IR
# lowerer currently remain separate authorities; this guard prevents a new
# lowerer spelling from becoming an unresolved-name hole while Q03 migrates
# both sides to one typed registry.

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
semantic_file="$repo_root/vendor/elisa-compiler/src/semantic/symbols.elisa"
registry_file="$repo_root/vendor/elisa-compiler/src/semantic/builtin_registry.elisa"
lowerer_file="$repo_root/src/ir/lower_ast.elisa"

for required_file in "$semantic_file" "$registry_file" "$lowerer_file"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'builtin surface: missing source file: %s\n' "$required_file" >&2
        exit 2
    fi
done

# The first list is the large literal seed row. The add_symbol rows immediately
# below it are part of the same semantic authority and must be included too.
semantic_names() {
    awk '
        /names: darray\[sview\] = \[/ { capture = 1 }
        capture { print }
        capture && /\]/ { exit }
    ' "$semantic_file" |
        rg -o '"[A-Za-z_][A-Za-z0-9_]*"' |
        tr -d '"'
    rg -o 'add_symbol\("[A-Za-z_][A-Za-z0-9_]*"' "$semantic_file" |
        sed 's/.*("//; s/"$//'
    # Registry migration may append a spelling to the caller-owned seed array
    # when editing the very long legacy literal would obscure the diff.
    rg -o 'names <- names\.push\("[A-Za-z_][A-Za-z0-9_]*"' "$semantic_file" |
        sed 's/.*push("//; s/"$//'
    # Registry-backed global spellings are seeded by the typed loop rather
    # than individual add_symbol calls; include that authoritative list here.
    sed -n '/def typed_builtin_names/,/^        def /p' "$registry_file" |
        rg -o '"[A-Za-z_][A-Za-z0-9_]*"' |
        tr -d '"'
}

lowerer_names() {
    # Global builtin dispatch is keyed by callee_name. Receiver method names
    # deliberately stay out of this comparison: they are type-directed and do
    # not need to be seeded as bare identifiers by semantic analysis.
    rg -o 'callee_name == "[A-Za-z_][A-Za-z0-9_]*"' "$lowerer_file" |
        sed 's/.*== "//; s/"$//' || true
}

semantic_sorted="$(semantic_names | sort -u)"
lowerer_sorted="$(lowerer_names | sort -u)"
missing="$(comm -23 <(printf '%s\n' "$lowerer_sorted") <(printf '%s\n' "$semantic_sorted"))"

printf 'semantic_seed_count\t%s\n' "$(printf '%s\n' "$semantic_sorted" | awk 'NF { count += 1 } END { print count + 0 }')"
printf 'lowerer_global_count\t%s\n' "$(printf '%s\n' "$lowerer_sorted" | awk 'NF { count += 1 } END { print count + 0 }')"
if [[ -n "$missing" ]]; then
    printf 'missing_semantic_seed\t%s\n' "$missing" >&2
    exit 1
fi

printf 'builtin surface audit: semantic seeds cover all direct global spellings; registry identity handles global lowering\n'
