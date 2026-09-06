#!/usr/bin/env bash

# Compiler-free audit for the partitioned, read-only migration inventory.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
roots_file="$repo_root/docs/migration-project-roots.tsv"
schema_file="$repo_root/docs/migration-inventory-schema.md"
coordinator="$repo_root/scripts/inventory_project_roots.sh"

for required_file in "$roots_file" "$schema_file" "$coordinator" "$repo_root/scripts/inventory_candidates.sh" "$repo_root/scripts/inventory_signals.sh"; do
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

bash -n "$coordinator" "$script_dir/inventory_candidates.sh" "$script_dir/inventory_signals.sh"
printf 'migration inventory audit: partition manifest and bounded read-only scanners present\n'
