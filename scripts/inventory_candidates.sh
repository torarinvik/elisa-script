#!/bin/sh

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
scan_root="${1:-$(CDPATH= cd -- "$script_dir/../.." && pwd)}"
if [ ! -d "$scan_root" ]; then
    echo "inventory_candidates: scan root does not exist: $scan_root" >&2
    exit 2
fi

# Keep the path-only census bounded before the candidate stream reaches sort.
# Dependency/cache trees are excluded consistently with the signal scanner;
# callers should split a larger project root into reviewable slices instead of
# turning discovery into an unbounded whole-drive operation.
max_scan_files=200000
scan_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/elisascript-candidate-scan.XXXXXX")" || {
    echo "inventory_candidates: unable to create private temporary directory" >&2
    exit 3
}
cleanup_scan_tmp() {
    rm -rf -- "$scan_tmp_dir"
}
trap cleanup_scan_tmp EXIT HUP INT TERM

scan_census_file="$scan_tmp_dir/census.paths"
if ! find "$scan_root" \
    \( -path '*/.git' -o -path '*/node_modules' -o -path '*/.venv' -o -path '*/__pycache__' -o -path '*/vendor' -o -path '*/third_party' \) -prune -o \
    -type f -print > "$scan_census_file" 2>/dev/null; then
    echo "inventory_candidates: regular-file traversal failed for $scan_root" >&2
    exit 3
fi
scan_file_count="$(wc -l < "$scan_census_file" | tr -d '[:space:]')"
case "$scan_file_count" in
    ''|*[!0-9]*)
        echo "inventory_candidates: unable to count regular files under $scan_root" >&2
        exit 3
        ;;
esac
if [ "$scan_file_count" -gt "$max_scan_files" ]; then
    echo "inventory_candidates: root contains $scan_file_count regular files; split the root (limit $max_scan_files)" >&2
    exit 3
fi

printf 'path\tkind\towner\tentrypoint\tdisposition\trisk\tnotes\n'

candidate_kind() {
    candidate_path="$1"
    case "$candidate_path" in
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

# The patterns are mutually exclusive, so a global sort/de-duplication pass is
# unnecessary. Materialize the bounded path list in a private temporary file;
# redirecting the state-machine reader from a regular file avoids keeping a
# producer pipe open while a shell `while read` waits for EOF on large roots.
candidate_paths_file="$scan_tmp_dir/candidate.paths"
if ! : > "$candidate_paths_file"; then
    echo "inventory_candidates: unable to create a private path-list file" >&2
    exit 3
fi

for candidate_pattern in '*.py' '*.pl' '*.pm' '*.awk' '*.sh' '*.bash' '*.zsh' '*.fish' 'Makefile' 'makefile'; do
    if rg --files --hidden \
        --glob '!.git/**' \
        --glob '!**/.git/**' \
        --glob '!**/node_modules/**' \
        --glob '!**/.venv/**' \
        --glob '!**/__pycache__/**' \
        --glob '!**/vendor/**' \
        --glob '!**/third_party/**' \
        -g "$candidate_pattern" "$scan_root" 2>/dev/null >> "$candidate_paths_file"; then
        :
    else
        rg_status=$?
        if [ "$rg_status" -ne 1 ]; then
            echo "inventory_candidates: filename search failed for pattern $candidate_pattern" >&2
            exit 3
        fi
    fi
done

while IFS= read -r candidate_path; do
    [ -n "$candidate_path" ] || continue
    kind="$(candidate_kind "$candidate_path")"
    risk="$(candidate_risk "$candidate_path")"
    disposition="$(candidate_disposition "$candidate_path")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$candidate_path" "$kind" unassigned unknown "$disposition" "$risk" 'read-only candidate; classify before porting or deletion'
done < "$candidate_paths_file"
