#!/bin/sh

# Read-only migration signal scanner. It reports executable files, interpreter
# shebangs, and inline legacy-interpreter invocations that an extension-only
# inventory can miss. It never sources, parses, imports, or executes a match.

set -u
LC_ALL=C
export LC_ALL

if [ "$#" -gt 1 ]; then
    echo "usage: inventory_signals.sh [CODING_PROJECTS_ROOT]" >&2
    exit 2
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
scan_root="${1:-$(CDPATH= cd -- "$script_dir/../.." && pwd)}"
if [ ! -d "$scan_root" ]; then
    echo "inventory_signals: scan root does not exist: $scan_root" >&2
    exit 2
fi

printf 'path\tsignal\tdetail\n'

{
    find "$scan_root" \
        \( -path '*/.git' -o -path '*/node_modules' -o -path '*/.venv' -o -path '*/__pycache__' -o -path '*/vendor' -o -path '*/third_party' \) -prune -o \
        -type f -perm -111 -print 2>/dev/null |
        while IFS= read -r path; do
            case "$path" in
                */.git/*) continue ;;
            esac
            printf '%s\texecutable-file\tpermission bit; inspect file type and shebang before classifying\n' "$path"
        done

    rg -l --hidden --no-messages --glob '!.git/**' --glob '!**/node_modules/**' --glob '!**/.venv/**' --glob '!**/__pycache__/**' --glob '!**/vendor/**' --glob '!**/third_party/**' \
        '^[[:space:]]*#![[:space:]]*(/[^[:space:]]*/)?(env[[:space:]]+)?(python3?|pypy3?|perl|awk|gawk|mawk|sh|bash|zsh|fish)([[:space:]]|$)' \
        "$scan_root" 2>/dev/null |
        while IFS= read -r path; do
            printf '%s\tlegacy-shebang\tinterpreter shebang; review runtime, argv, cwd, environment, and exit behavior\n' "$path"
        done

    rg -l --hidden --no-messages --glob '!.git/**' --glob '!**/node_modules/**' --glob '!**/.venv/**' --glob '!**/__pycache__/**' --glob '!**/vendor/**' --glob '!**/third_party/**' \
        '(^|[^[:alnum:]_])(python3?|pypy3?)[[:space:]]+-c([[:space:]]|$)|(^|[^[:alnum:]_])perl[[:space:]]+-e([[:space:]]|$)|(^|[^[:alnum:]_])(g?awk|mawk)([[:space:]]|$)' \
        "$scan_root" 2>/dev/null |
        while IFS= read -r path; do
            printf '%s\tinline-legacy-invocation\tcontent references python/perl/awk command syntax; inspect callers and embedded program text\n' "$path"
        done
} | sort -u
