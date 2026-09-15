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

case "$0" in
    */*)
        script_dir_operand="${0%/*}"
        if [ -z "$script_dir_operand" ]; then
            script_dir_operand=/
        fi
        ;;
    *)
        script_dir_operand=.
        ;;
esac
script_dir="$(CDPATH= cd -- "$script_dir_operand" && pwd)"
scan_root="${1:-$(CDPATH= cd -- "$script_dir/../.." && pwd)}"
tab="$(printf '\t')"
carriage_return="$(printf '\r')"
line_feed="$(printf '\nX')"
line_feed="${line_feed%X}"
case "$scan_root" in
    *"$tab"*|*"$carriage_return"*|*"$line_feed"*)
        echo "inventory_signals: scan root contains a TSV delimiter or line break" >&2
        exit 2
        ;;
esac
if [ ! -d "$scan_root" ]; then
    echo "inventory_signals: scan root does not exist: $scan_root" >&2
    exit 2
fi

# Normalize `..` logically first, then follow an explicit root symlink once.
# A sentinel preserves a trailing newline in the physical path long enough for
# the delimiter check below; command substitution normally strips it.
physical_scan_root="$(
    CDPATH= cd -L -- "$scan_root" 2>/dev/null || exit 1
    pwd -P || exit 1
    printf '.'
)" || {
    echo "inventory_signals: unable to resolve scan root" >&2
    exit 3
}
physical_scan_root="${physical_scan_root%.}"
physical_scan_root="${physical_scan_root%?}"
case "$physical_scan_root" in
    *"$tab"*|*"$carriage_return"*|*"$line_feed"*)
        echo "inventory_signals: scan root contains a TSV delimiter or line break" >&2
        exit 2
        ;;
esac
scan_root="$physical_scan_root"

# find prunes these names even at the starting point. Make that behavior
# explicit for rg too, whose globs are relative to the selected root.
scan_root_name="${scan_root##*/}"
case "$scan_root_name" in
    .git|node_modules|.venv|__pycache__|vendor|third_party)
        printf 'path\tsignal\tdetail\n'
        exit 0
        ;;
esac

# Resolve every required external utility before emitting output or starting a
# scan. This gives callers the same stable missing-tool status and diagnostic
# rather than leaking shell-specific "command not found" output later.
for required_tool in find rg sort; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        printf 'inventory_signals: required tool not found: %s\n' "$required_tool" >&2
        exit 127
    fi
done

# Signal discovery is intentionally bounded before any content search starts.
# A broad projects directory can contain generated or dependency trees that are
# individually harmless but collectively expensive; callers should split such
# roots rather than allowing the scanner to become an unbounded workload. The
# count is conservative for filenames containing newlines, which is safe for a
# discovery-only report.
max_scan_files=200000
max_scan_depth=64
max_scan_file_bytes='8M'

signal_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/elisascript-signals.XXXXXX")" || {
    echo "inventory_signals: unable to create private temporary directory" >&2
    exit 3
}
cleanup_signal_tmp() {
    rm -rf -- "$signal_tmp_dir"
}
trap cleanup_signal_tmp EXIT HUP INT TERM

depth_violation_paths="$signal_tmp_dir/depth.paths"
# BSD find has no GNU -maxdepth. This portable predicate runs only for
# directories: shallow directories return false and are descended into, while
# a directory below the allowed relative depth prints itself and -prune stops
# traversal. The shell helper receives the path as an argument, so unusual
# characters are not reparsed as find syntax.
if ! find "$scan_root" \
    \( -path '*/.git' -o -path '*/node_modules' -o -path '*/.venv' -o -path '*/__pycache__' -o -path '*/vendor' -o -path '*/third_party' \) -prune -o \
    \( -type d -exec sh -c '
        root=$1
        candidate=$2
        limit=$3
        depth=0
        if [ "$candidate" != "$root" ]; then
            # `${root}/` would be `//` for the filesystem root, which does
            # not match the single slash prefix in a find-produced path.
            # Strip the root spelling itself in that case so `/child` is
            # measured as one descendant directory rather than two.
            if [ "$root" = "/" ]; then
                relative=${candidate#/}
            else
                relative=${candidate#"$root"/}
            fi
            depth=1
            while :; do
                case "$relative" in
                    */*)
                        relative=${relative#*/}
                        depth=$((depth + 1))
                        ;;
                    *)
                        break
                        ;;
                esac
            done
        fi
        [ "$depth" -gt "$limit" ]
    ' inventory-signals-depth "$scan_root" {} "$max_scan_depth" \; -print -prune \) \
    > "$depth_violation_paths" 2>/dev/null; then
    echo "inventory_signals: executable-file traversal failed for $scan_root" >&2
    exit 3
fi
if [ -s "$depth_violation_paths" ]; then
    echo "inventory_signals: executable-file traversal failed for $scan_root" >&2
    exit 3
fi

scan_file_count="$(find "$scan_root" \
    \( -path '*/.git' -o -path '*/node_modules' -o -path '*/.venv' -o -path '*/__pycache__' -o -path '*/vendor' -o -path '*/third_party' \) -prune -o \
    -type f -print 2>/dev/null | wc -l | tr -d '[:space:]')"
case "$scan_file_count" in
    ''|*[!0-9]*)
        echo "inventory_signals: unable to count regular files under $scan_root" >&2
        exit 3
        ;;
esac
if [ "$scan_file_count" -gt "$max_scan_files" ]; then
    echo "inventory_signals: root contains $scan_file_count regular files; split the root (limit $max_scan_files)" >&2
    exit 3
fi

executable_paths="$signal_tmp_dir/executable.paths"
shebang_paths="$signal_tmp_dir/shebang.paths"
inline_paths="$signal_tmp_dir/inline.paths"

if ! find "$scan_root" \
    \( -path '*/.git' -o -path '*/node_modules' -o -path '*/.venv' -o -path '*/__pycache__' -o -path '*/vendor' -o -path '*/third_party' \) -prune -o \
    -type f -perm -111 -print > "$executable_paths" 2>/dev/null; then
    echo "inventory_signals: executable-file traversal failed for $scan_root" >&2
    exit 3
fi

if rg -l --hidden --no-messages --max-filesize "$max_scan_file_bytes" --glob '!.git/**' --glob '!**/node_modules/**' --glob '!**/.venv/**' --glob '!**/__pycache__/**' --glob '!**/vendor/**' --glob '!**/third_party/**' \
    '^[[:space:]]*#![[:space:]]*(/[^[:space:]]*/)?(env[[:space:]]+)?(python3?|pypy3?|perl|awk|gawk|mawk|sh|bash|zsh|fish)([[:space:]]|$)' \
    "$scan_root" > "$shebang_paths" 2>/dev/null; then
    :
else
    rg_status=$?
    if [ "$rg_status" -ne 1 ]; then
        echo "inventory_signals: shebang search failed for $scan_root" >&2
        exit 3
    fi
fi

if rg -l --hidden --no-messages --max-filesize "$max_scan_file_bytes" --glob '!.git/**' --glob '!**/node_modules/**' --glob '!**/.venv/**' --glob '!**/__pycache__/**' --glob '!**/vendor/**' --glob '!**/third_party/**' \
    '(^|[^[:alnum:]_])(python3?|pypy3?)[[:space:]]+-c([[:space:]]|$)|(^|[^[:alnum:]_])perl[[:space:]]+-e([[:space:]]|$)|(^|[^[:alnum:]_])(g?awk|mawk)([[:space:]]|$)' \
    "$scan_root" > "$inline_paths" 2>/dev/null; then
    :
else
    rg_status=$?
    if [ "$rg_status" -ne 1 ]; then
        echo "inventory_signals: inline-invocation search failed for $scan_root" >&2
        exit 3
    fi
fi

printf 'path\tsignal\tdetail\n'
{
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        printf '%s\texecutable-file\tpermission bit; inspect file type and shebang before classifying\n' "$path"
    done < "$executable_paths"
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        printf '%s\tlegacy-shebang\tinterpreter shebang; review runtime, argv, cwd, environment, and exit behavior\n' "$path"
    done < "$shebang_paths"
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        printf '%s\tinline-legacy-invocation\tcontent references python/perl/awk command syntax; inspect callers and embedded program text\n' "$path"
    done < "$inline_paths"
} | sort -u
