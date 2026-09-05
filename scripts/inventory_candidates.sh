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

printf 'path\tkind\towner\tentrypoint\tdisposition\trisk\tnotes\n'

candidate_kind() {
    candidate_path="$1"
    case "$candidate_path" in
        */Makefile|*/makefile) printf '%s' makefile ;;
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

for candidate_pattern in '*.py' '*.pl' '*.pm' '*.awk' '*.sh' '*.bash' '*.zsh' '*.fish' 'Makefile' 'makefile'; do
    rg --files --hidden -g "$candidate_pattern" "$scan_root" 2>/dev/null || true
done | sort -u | while IFS= read -r candidate_path; do
    [ -n "$candidate_path" ] || continue
    kind="$(candidate_kind "$candidate_path")"
    risk="$(candidate_risk "$candidate_path")"
    disposition="$(candidate_disposition "$candidate_path")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$candidate_path" "$kind" unassigned unknown "$disposition" "$risk" 'read-only candidate; classify before porting or deletion'
done
