#!/usr/bin/env bash

# Compiler-free audit for the partitioned migration-root manifest.
# This checks metadata and declared directory boundaries only; it never runs a
# scanner, reads candidate contents, or executes a legacy workflow.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
coding_projects_root="${1:-$(CDPATH= cd -- "$script_dir/../../.." && pwd)}"
roots_file="${2:-$repo_root/docs/migration-project-roots.tsv}"

if [[ ! -d "$coding_projects_root" ]]; then
    printf 'migration roots audit: coding-projects root does not exist: %s\n' "$coding_projects_root" >&2
    exit 2
fi
if [[ ! -f "$roots_file" ]]; then
    printf 'migration roots audit: manifest does not exist: %s\n' "$roots_file" >&2
    exit 2
fi

canonical_coding_projects_root="$(CDPATH= cd -- "$coding_projects_root" && pwd -P)" || {
    printf 'migration roots audit: unable to canonicalize coding-projects root\n' >&2
    exit 2
}

if ! awk -F '\t' '
    NR == 1 {
        if ($0 != "# name\trelative_path\towner\treview_status") bad = 1
        next
    }
    NF == 0 { next }
    {
        if (NF != 4 || $1 == "" || $2 == "" || $3 == "" || $4 == "") bad = 1
        if ($2 ~ /^\// || $2 ~ /(^|\/)\.\.(\/|$)/ || $2 ~ /^\.\//) bad = 1
        if ($4 !~ /^(pending|reviewed|blocked)$/) bad = 1
        if ($4 == "reviewed" && $3 == "unassigned") bad = 1
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
    printf 'migration roots audit: malformed, duplicated, unsafe, or unowned reviewed row\n' >&2
    exit 1
fi

tab="$(printf '\t')"
while IFS="$tab" read -r root_name relative_path owner review_status; do
    [[ "$root_name" == "# name" || -z "$root_name" ]] && continue
    root_path="$coding_projects_root/$relative_path"
    if [[ ! -d "$root_path" ]]; then
        printf 'migration roots audit: declared root is missing: %s\n' "$root_path" >&2
        exit 1
    fi
    canonical_root_path="$(CDPATH= cd -- "$root_path" && pwd -P)" || {
        printf 'migration roots audit: unable to canonicalize declared root: %s\n' "$root_path" >&2
        exit 1
    }
    case "$canonical_root_path" in
        "$canonical_coding_projects_root"|"$canonical_coding_projects_root"/*)
            ;;
        *)
            printf 'migration roots audit: declared root escapes coding-projects tree through a symlink: %s\n' "$root_path" >&2
            exit 1
            ;;
    esac
done < "$roots_file"

printf 'migration roots audit: manifest shape, ownership, and declared directories are valid\n'
