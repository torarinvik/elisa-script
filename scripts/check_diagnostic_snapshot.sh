#!/usr/bin/env bash
set -euo pipefail

# Compiler-free consistency guard for the launcher diagnostic snapshot API.
# Every host-visible field in ElisascriptProgramDiagnostic must participate in
# both the compact fingerprint and the collision-free structural comparison.

script_dir=$(cd "$(dirname "$0")" && pwd -P)
repo_dir=$(cd "$script_dir/.." && pwd -P)
runner="$repo_dir/src/ir/runner.elisa"

[[ -f "$runner" ]] || { echo "diagnostic snapshot audit: missing runner source" >&2; exit 1; }

fields=$(awk '
    /^        struct ElisascriptProgramDiagnostic:/ { inside=1; next }
    inside && /^$/ { exit }
    inside && /^            [a-z_][a-z0-9_]*:/ {
        field=$1
        sub(/:$/, "", field)
        print field
    }
' "$runner")

[[ -n "$fields" ]] || { echo "diagnostic snapshot audit: no diagnostic fields found" >&2; exit 1; }

fingerprint_start=$(rg -n '^        def elisascript_program_diagnostic_snapshot_fingerprint' "$runner" | cut -d: -f1)
equal_start=$(rg -n '^        def elisascript_program_diagnostic_snapshot_equal' "$runner" | cut -d: -f1)
[[ -n "$fingerprint_start" && -n "$equal_start" ]] || { echo "diagnostic snapshot audit: missing snapshot operations" >&2; exit 1; }

fingerprint_body=$(sed -n "${fingerprint_start},${equal_start}p" "$runner")
equal_body=$(sed -n "${equal_start},$((equal_start + 80))p" "$runner")

missing=0
while IFS= read -r field; do
    [[ "$field" == "execution" ]] && continue
    if ! rg -q "diagnostic\\.${field}\\b" <<<"$fingerprint_body"; then
        echo "diagnostic snapshot audit: fingerprint omits $field" >&2
        missing=1
    fi
    if ! rg -q "left\\.${field}\\b" <<<"$equal_body" || ! rg -q "right\\.${field}\\b" <<<"$equal_body"; then
        echo "diagnostic snapshot audit: structural equality omits $field" >&2
        missing=1
    fi
done <<<"$fields"

if (( missing != 0 )); then
    exit 1
fi

printf 'diagnostic snapshot audit: %s fields covered (execution intentionally excluded)\n' "$(printf '%s\n' "$fields" | awk '$0 != "execution" { count++ } END { print count + 0 }')"
