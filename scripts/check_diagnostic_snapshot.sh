#!/usr/bin/env bash
set -euo pipefail

# Compiler-free consistency guard for the launcher diagnostic snapshot API.
# Every host-visible field in ElisascriptProgramDiagnostic must participate in
# both the compact fingerprint and the collision-free structural comparison.

script_dir=$(cd "$(dirname "$0")" && pwd -P)
repo_dir=$(cd "$script_dir/.." && pwd -P)
runner="${1:-$repo_dir/src/ir/runner.elisa}"
candidate="$script_dir/check_diagnostic_snapshot.elisascript"
bounded_reader="$repo_dir/src/runtime/bounded_text_posix.elisa"

if (( $# > 1 )); then
    echo "usage: diagnostic snapshot audit [runner-source]" >&2
    exit 2
fi

[[ -f "$candidate" ]] || { echo "diagnostic snapshot audit: missing Elisascript candidate" >&2; exit 1; }
[[ -f "$bounded_reader" ]] || { echo "diagnostic snapshot audit: missing shared bounded text reader" >&2; exit 1; }
rg -Fq 'include "../src/runtime/bounded_text_posix.elisa"' "$candidate" || { echo "diagnostic snapshot audit: candidate does not use shared bounded text reader" >&2; exit 1; }
rg -Fq 'EsBoundedText::read_utf8(input_path, Limits::SOURCE_BYTES)' "$candidate" || { echo "diagnostic snapshot audit: candidate does not use bounded UTF-8 read" >&2; exit 1; }
for required in 'MAX_BYTES: usize = 16777216' 'maximum_bytes - bytes.count' 'probe_capacity: usize = remaining + 1' 'DarwinOpenFlags::NONBLOCK' 'ReadError.LimitExceeded' 'text_is_valid_utf8' 'stable_file(opened, final_opened)'; do
    rg -Fq "$required" "$bounded_reader" || { echo "diagnostic snapshot audit: shared reader is missing $required" >&2; exit 1; }
done
if rg -Fq 'read_text(' "$candidate" "$bounded_reader"; then
    echo "diagnostic snapshot audit: unbounded read_text API is forbidden" >&2
    exit 1
fi

[[ -f "$runner" ]] || { echo "diagnostic snapshot audit: missing runner source" >&2; exit 1; }

readonly MAX_SOURCE_BYTES=262144
readonly MAX_FIELDS=256
readonly MAX_FIELD_BYTES=128
source_bytes=$(LC_ALL=C wc -c < "$runner")
if (( source_bytes > MAX_SOURCE_BYTES )); then
    echo "diagnostic snapshot audit: runner source exceeds audit limit" >&2
    exit 1
fi
if LC_ALL=C awk 'BEGIN { cr=sprintf("%c", 13) } { line=$0; sub(cr "$", "", line); if (index(line, cr) > 0) exit 1 }' "$runner"; then
    :
else
    echo "diagnostic snapshot audit: bare carriage return is unsupported" >&2
    exit 1
fi
if [[ $(LC_ALL=C tail -c 1 "$runner" | od -An -tu1 | tr -d '[:space:]') == "13" ]]; then
    echo "diagnostic snapshot audit: bare carriage return is unsupported" >&2
    exit 1
fi

fields=$(awk '
    BEGIN { cr=sprintf("%c", 13) }
    { sub(cr "$", "") }
    /^        struct ElisascriptProgramDiagnostic:/ { inside=1; next }
    inside && /^$/ { exit }
    inside && /^            [a-z_][a-z0-9_]*[[:space:]]*:/ {
        field=$0
        sub(/^            /, "", field)
        sub(/[[:space:]]*:.*$/, "", field)
        print field
    }
' "$runner")

[[ -n "$fields" ]] || { echo "diagnostic snapshot audit: no diagnostic fields found" >&2; exit 1; }

field_count=$(printf '%s\n' "$fields" | LC_ALL=C wc -l)
if (( field_count > MAX_FIELDS )); then
    echo "diagnostic snapshot audit: diagnostic field count exceeds audit limit" >&2
    exit 1
fi
if LC_ALL=C awk -v maximum="$MAX_FIELD_BYTES" 'length($0) > maximum { exit 1 }' <<<"$fields"; then
    :
else
    echo "diagnostic snapshot audit: diagnostic field name exceeds audit limit" >&2
    exit 1
fi

fingerprint_body=$(awk -v header='        def elisascript_program_diagnostic_snapshot_fingerprint' '
    BEGIN { cr=sprintf("%c", 13) }
    { sub(cr "$", "") }
    !inside && index($0, header) == 1 { inside=1 }
    inside && count++ > 0 && /^        def / { exit }
    inside { print }
' "$runner")
equal_body=$(awk -v header='        def elisascript_program_diagnostic_snapshot_equal' '
    BEGIN { cr=sprintf("%c", 13) }
    { sub(cr "$", "") }
    !inside && index($0, header) == 1 { inside=1 }
    inside && count++ > 0 && /^        def / { exit }
    inside { print }
' "$runner")
[[ -n "$fingerprint_body" && -n "$equal_body" ]] || { echo "diagnostic snapshot audit: missing snapshot operations" >&2; exit 1; }

missing=0
while IFS= read -r field; do
    [[ "$field" == "execution" ]] && continue
    diagnostic_pattern="(^|[^A-Za-z0-9_])diagnostic\\.${field}([^A-Za-z0-9_]|$)"
    left_pattern="(^|[^A-Za-z0-9_])left\\.${field}([^A-Za-z0-9_]|$)"
    right_pattern="(^|[^A-Za-z0-9_])right\\.${field}([^A-Za-z0-9_]|$)"
    if ! rg -q "$diagnostic_pattern" <<<"$fingerprint_body"; then
        echo "diagnostic snapshot audit: fingerprint omits $field" >&2
        missing=1
    fi
    if ! rg -q "$left_pattern" <<<"$equal_body" || ! rg -q "$right_pattern" <<<"$equal_body"; then
        echo "diagnostic snapshot audit: structural equality omits $field" >&2
        missing=1
    fi
done <<<"$fields"

if (( missing != 0 )); then
    exit 1
fi

printf 'diagnostic snapshot audit: %s fields covered (execution intentionally excluded)\n' "$(printf '%s\n' "$fields" | awk '$0 != "execution" { count++ } END { print count + 0 }')"
