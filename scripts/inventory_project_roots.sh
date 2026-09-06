#!/bin/sh

# Run the read-only migration scanners one declared project root at a time.
# This coordinator never sources, parses, imports, or executes a legacy file.
# Each scanner keeps its own regular-file/content budget; an oversized root
# fails closed instead of turning discovery into a whole-drive workload.

set -u
LC_ALL=C
export LC_ALL

if [ "$#" -gt 2 ]; then
    echo "usage: inventory_project_roots.sh [CODING_PROJECTS_ROOT] [ROOTS_TSV]" >&2
    exit 2
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
coding_projects_root="${1:-$(CDPATH= cd -- "$script_dir/../../.." && pwd)}"
roots_tsv="${2:-$script_dir/../docs/migration-project-roots.tsv}"

if [ ! -d "$coding_projects_root" ]; then
    echo "inventory_project_roots: coding-projects root does not exist: $coding_projects_root" >&2
    exit 2
fi
if [ ! -f "$roots_tsv" ]; then
    echo "inventory_project_roots: root manifest does not exist: $roots_tsv" >&2
    exit 2
fi

workspace_tmp="$(mktemp -d "${TMPDIR:-/tmp}/elisascript-inventory-roots.XXXXXX")" || {
    echo "inventory_project_roots: unable to create private temporary directory" >&2
    exit 3
}
cleanup_inventory_tmp() {
    rm -rf -- "$workspace_tmp"
}
trap cleanup_inventory_tmp EXIT HUP INT TERM

printf 'root_name\troot_path\tpath\tkind\towner\tentrypoint\tdisposition\trisk\tnotes\n'

tab="$(printf '\t')"
line_number=0
while IFS="$tab" read -r root_name relative_path owner review_status; do
    line_number=$((line_number + 1))
    case "$root_name" in
        ''|'# name')
            continue
            ;;
    esac
    if [ -z "$relative_path" ] || [ -z "$owner" ] || [ -z "$review_status" ]; then
        echo "inventory_project_roots: malformed manifest row $line_number" >&2
        exit 3
    fi
    case "$relative_path" in
        /*|*'..'*|*'\000'*)
            echo "inventory_project_roots: unsafe relative path on row $line_number" >&2
            exit 3
            ;;
    esac
    root_path="$coding_projects_root/$relative_path"
    if [ ! -d "$root_path" ]; then
        echo "inventory_project_roots: declared root is missing: $root_path" >&2
        exit 3
    fi

    candidate_output="$workspace_tmp/candidates.$line_number.tsv"
    signal_output="$workspace_tmp/signals.$line_number.tsv"
    if ! "$script_dir/inventory_candidates.sh" "$root_path" >"$candidate_output"; then
        echo "inventory_project_roots: candidate scan failed for $root_name" >&2
        exit 3
    fi
    if ! "$script_dir/inventory_signals.sh" "$root_path" >"$signal_output"; then
        echo "inventory_project_roots: signal scan failed for $root_name" >&2
        exit 3
    fi

    tail -n +2 "$candidate_output" | while IFS="$tab" read -r path kind candidate_owner entrypoint disposition risk notes; do
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$root_name" "$root_path" "$path" "$kind" "$owner" "$entrypoint" "$disposition" "$risk" "manifest=$review_status; scanner_owner=$candidate_owner; $notes"
    done
    tail -n +2 "$signal_output" | while IFS="$tab" read -r path signal detail; do
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$root_name" "$root_path" "$path" signal "$owner" none review "$signal" "manifest=$review_status; $detail"
    done
done < "$roots_tsv"
