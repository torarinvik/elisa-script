#!/bin/bash

# Read-only migration inventory generator. It enumerates candidate paths and
# emits TSV records; it never sources, parses, imports, or executes a legacy
# script. The output is intentionally a candidate manifest, not an acceptance
# decision.

set -u
LC_ALL=C
export LC_ALL

if [ "$#" -gt 1 ]; then
    echo "usage: inventory_candidates.sh [CODING_PROJECTS_ROOT]" >&2
    exit 2
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
requested_root="${1:-$(CDPATH= cd -- "$script_dir/../.." && pwd)}"
case "$requested_root" in
    *$'\t'*|*$'\r'*|*$'\n'*)
        echo "inventory_candidates: unsupported scan root contains a TSV delimiter or line break" >&2
        exit 2
        ;;
esac
if [ ! -d "$requested_root" ]; then
    echo "inventory_candidates: scan root does not exist: $requested_root" >&2
    exit 2
fi
scan_root="$(CDPATH= cd -- "$requested_root" && pwd -P && printf '.')" || {
    echo "inventory_candidates: unable to resolve scan root" >&2
    exit 3
}
scan_root="${scan_root%$'\n'.}"

tab="$(printf '\t')"
carriage_return="$(printf '\r')"
newline='
'
case "$scan_root" in
    *"$tab"*|*"$carriage_return"*|*"$newline"*)
        echo "inventory_candidates: unsupported scan root contains a TSV delimiter or line break" >&2
        exit 2
        ;;
esac

max_scan_files=200000
max_scan_directories=200000
max_scan_depth=64
max_scan_entries=262144
max_total_path_bytes=67108864
max_candidate_path_bytes=41943040
max_output_bytes=67108864

scan_tmp_dir="$(mktemp -d "/tmp/elisascript-candidate-scan.XXXXXX")" || {
    echo "inventory_candidates: unable to create private temporary directory" >&2
    exit 3
}
cleanup_scan_tmp() {
    rm -rf -- "$scan_tmp_dir"
}
trap cleanup_scan_tmp EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

candidate_paths_file="$scan_tmp_dir/candidate.paths"
sorted_candidate_paths_file="$scan_tmp_dir/candidate.paths.sorted"
if ! : > "$candidate_paths_file"; then
    echo "inventory_candidates: unable to create a private path-list file" >&2
    exit 3
fi

is_excluded_directory_name() {
    case "$1" in
        .git|node_modules|.venv|__pycache__|vendor|third_party) return 0 ;;
        *) return 1 ;;
    esac
}

scan_root_name="${scan_root##*/}"

candidate_kind() {
    candidate_path="$1"
    case "$candidate_path" in
        CMakeLists.txt|*/CMakeLists.txt|*.cmake) printf '%s' cmake ;;
        Makefile|makefile|*/Makefile|*/makefile) printf '%s' makefile ;;
        *.py) printf '%s' python ;;
        *.pl|*.pm) printf '%s' perl ;;
        *.awk) printf '%s' awk ;;
        *.sh|*.bash|*.zsh|*.fish) printf '%s' shell ;;
        *) printf '%s' unknown ;;
    esac
}

candidate_risk() {
    candidate_path="$1"
    case "$candidate_path" in
        */release/*|*/deploy/*|*/publish/*|*/install/*) printf '%s' release ;;
        */test/*|*/tests/*|*/fixture*/*) printf '%s' test ;;
        */build/*|*/target/*|*/.github/*|*/.gitlab/*|*/.circleci/*) printf '%s' build ;;
        *) printf '%s' unknown ;;
    esac
}

candidate_disposition() {
    candidate_path="$1"
    case "$candidate_path" in
        */vendor/*|*/third_party/*|*/node_modules/*|*/.git/*) printf '%s' retain-external ;;
        */build/*|*/target/*|*/dist/*|*/generated/*) printf '%s' classify-generated ;;
        *) printf '%s' classify ;;
    esac
}

scan_file_count=0
scan_directory_count=0
scan_entry_count=0
total_path_bytes=0
candidate_path_bytes=0
if ! is_excluded_directory_name "$scan_root_name"; then
find "$scan_root" -mindepth 1 \
    \( -type d \( -name '.git' -o -name 'node_modules' -o -name '.venv' -o -name '__pycache__' -o -name 'vendor' -o -name 'third_party' \) -print0 -prune \) \
    -o -print0 2>/dev/null | while IFS= read -r -d '' scan_path; do
    scan_entry_count=$((scan_entry_count + 1))
    if [ "$scan_entry_count" -gt "$max_scan_entries" ]; then
        echo "inventory_candidates: traversal failed or exceeded a traversal limit for $scan_root" >&2
        exit 3
    fi

    case "$scan_path" in
        *"$tab"*|*"$carriage_return"*|*"$newline"*)
            echo "inventory_candidates: unsupported path contains a TSV delimiter or line break" >&2
            exit 3
            ;;
    esac

    path_bytes=${#scan_path}
    if [ "$total_path_bytes" -gt "$max_total_path_bytes" ] || [ "$path_bytes" -gt "$((max_total_path_bytes - total_path_bytes))" ]; then
        echo "inventory_candidates: aggregate path bytes exceed limit ($max_total_path_bytes)" >&2
        exit 3
    fi
    total_path_bytes=$((total_path_bytes + path_bytes))

    if [ -d "$scan_path" ] && [ ! -L "$scan_path" ]; then
        directory_name="${scan_path##*/}"
        if ! is_excluded_directory_name "$directory_name"; then
            if [ "$scan_root" = "/" ]; then
                relative_scan_path="${scan_path#/}"
            else
                relative_scan_path="${scan_path#"$scan_root"/}"
            fi
            relative_scan_slashes="${relative_scan_path//[^/]/}"
            scan_depth=$((${#relative_scan_slashes} + 1))
            if [ "$scan_depth" -gt "$max_scan_depth" ]; then
                echo "inventory_candidates: directory depth exceeds limit ($max_scan_depth) for $scan_root" >&2
                exit 3
            fi
            scan_directory_count=$((scan_directory_count + 1))
            if [ "$scan_directory_count" -gt "$max_scan_directories" ]; then
                echo "inventory_candidates: directory count exceeds limit ($max_scan_directories)" >&2
                exit 3
            fi
        fi
        continue
    fi
    if [ -L "$scan_path" ] || [ ! -f "$scan_path" ]; then
        continue
    fi

    scan_file_count=$((scan_file_count + 1))
    if [ "$scan_file_count" -gt "$max_scan_files" ]; then
        echo "inventory_candidates: root contains more than $max_scan_files regular files; split the root (limit $max_scan_files)" >&2
        exit 3
    fi

    kind="$(candidate_kind "$scan_path")"
    [ "$kind" != unknown ] || continue
    if [ "$candidate_path_bytes" -gt "$max_candidate_path_bytes" ] || [ "$path_bytes" -gt "$((max_candidate_path_bytes - candidate_path_bytes))" ]; then
        echo "inventory_candidates: candidate path bytes exceed limit ($max_candidate_path_bytes)" >&2
        exit 3
    fi
    candidate_path_bytes=$((candidate_path_bytes + path_bytes))
    if ! printf '%s\n' "$scan_path" >> "$candidate_paths_file"; then
        echo "inventory_candidates: unable to append a candidate path" >&2
        exit 3
    fi
done
pipeline_status=("${PIPESTATUS[@]}")
find_status="${pipeline_status[0]}"
inventory_status="${pipeline_status[1]}"
if [ "$inventory_status" -ne 0 ]; then
    exit "$inventory_status"
fi
if [ "$find_status" -ne 0 ]; then
    echo "inventory_candidates: traversal failed or exceeded a traversal limit for $scan_root" >&2
    exit 3
fi
fi

if ! LC_ALL=C sort -u "$candidate_paths_file" > "$sorted_candidate_paths_file"; then
    echo "inventory_candidates: unable to sort candidate paths" >&2
    exit 3
fi

header='path	kind	owner	entrypoint	disposition	risk	notes'
notes='read-only candidate; classify before porting or deletion'
output_bytes=$((${#header} + 1))
while IFS= read -r candidate_path; do
    [ -n "$candidate_path" ] || continue
    kind="$(candidate_kind "$candidate_path")"
    risk="$(candidate_risk "$candidate_path")"
    disposition="$(candidate_disposition "$candidate_path")"
    printf -v record '%s\t%s\t%s\t%s\t%s\t%s\t%s' "$candidate_path" "$kind" unassigned unknown "$disposition" "$risk" "$notes"
    record_bytes=$((${#record} + 1))
    if [ "$output_bytes" -gt "$max_output_bytes" ] || [ "$record_bytes" -gt "$((max_output_bytes - output_bytes))" ]; then
        echo "inventory_candidates: manifest output exceeds limit ($max_output_bytes)" >&2
        exit 3
    fi
    output_bytes=$((output_bytes + record_bytes))
done < "$sorted_candidate_paths_file"

printf '%s\n' "$header"
while IFS= read -r candidate_path; do
    [ -n "$candidate_path" ] || continue
    kind="$(candidate_kind "$candidate_path")"
    risk="$(candidate_risk "$candidate_path")"
    disposition="$(candidate_disposition "$candidate_path")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$candidate_path" "$kind" unassigned unknown "$disposition" "$risk" "$notes"
done < "$sorted_candidate_paths_file"
