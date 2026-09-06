#!/usr/bin/env bash

# Compiler-free audit for the partitioned, read-only migration inventory.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
roots_file="$repo_root/docs/migration-project-roots.tsv"
schema_file="$repo_root/docs/migration-inventory-schema.md"
coordinator="$repo_root/scripts/inventory_project_roots.sh"
review_file="$repo_root/docs/migration-review-current.tsv"
review_audit="$repo_root/scripts/check_migration_review.sh"

for required_file in "$roots_file" "$schema_file" "$review_file" "$review_audit" "$coordinator" "$repo_root/scripts/inventory_candidates.sh" "$repo_root/scripts/inventory_signals.sh"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'migration inventory audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

if [[ ! -x "$coordinator" ]]; then
    printf 'migration inventory audit: coordinator is not executable\n' >&2
    exit 1
fi
if ! rg -q '^# name[[:space:]]+relative_path[[:space:]]+owner[[:space:]]+review_status$' "$roots_file"; then
    printf 'migration inventory audit: root manifest header is invalid\n' >&2
    exit 1
fi

# Validate the complete manifest shape without touching any declared project
# root. Duplicate names/paths would make a combined report ambiguous, and an
# unknown review state would be impossible for downstream migration tooling to
# interpret deterministically.
if ! awk -F '\t' '
    NR == 1 { next }
    NF == 0 { next }
    {
        if (NF != 4) { bad = 1; next }
        if ($1 == "" || $2 == "" || $3 == "" || $4 == "") bad = 1
        if ($2 ~ /^\// || $2 ~ /(^|\/)\.\.(\/|$)/ || $2 ~ /^\.\//) bad = 1
        if ($4 !~ /^(pending|reviewed|blocked)$/) bad = 1
        names[$1]++
        paths[$2]++
        rows++
    }
    END {
        for (name in names) if (names[name] != 1) bad = 1
        for (path in paths) if (paths[path] != 1) bad = 1
        if (rows == 0 || bad) exit 1
    }
' "$roots_file"; then
    printf 'migration inventory audit: manifest rows are malformed, unsafe, duplicated, or use an unknown review state\n' >&2
    exit 1
fi

tab="$(printf '\t')"
for root_name in 'C++ projects' 'Elisa Projects' 'FSharpProjects' 'Go projects' 'Haskell Projects' 'Java Projects' 'Lean Projects' 'Ocaml Projects' 'Python Projects' 'Rust Projects' 'Swift Projects'; do
    if ! rg -Fq "${root_name}${tab}" "$roots_file"; then
        printf 'migration inventory audit: missing declared root %s\n' "$root_name" >&2
        exit 1
    fi
done

if ! rg -q 'inventory_candidates\.sh' "$schema_file" || ! rg -q 'inventory_signals\.sh' "$schema_file" || ! rg -q 'inventory_project_roots\.sh' "$schema_file"; then
    printf 'migration inventory audit: schema omits one of the read-only scanners\n' >&2
    exit 1
fi

bash -n "$coordinator" "$script_dir/inventory_candidates.sh" "$script_dir/inventory_signals.sh" "$review_audit"
printf 'migration inventory audit: partition manifest and bounded read-only scanners present\n'
