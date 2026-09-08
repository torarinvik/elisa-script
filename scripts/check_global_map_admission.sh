#!/usr/bin/env bash

# Compiler-free audit for defensive global map initializer admission.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
verifier="$repo_root/src/ir/ir_verify.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$interpreter" "$verifier" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || {
        printf 'global map admission audit: missing %s\n' "$required_file" >&2
        exit 1
    }
done

global_body="$(awk '
    /def global_value\(/ { inside = 1 }
    inside { print }
    inside && /^        def / && $0 !~ /def global_value\(/ { exit }
' "$interpreter")"
guard_line="$(printf '%s\n' "$global_body" | awk '/binding\.aggregate_values\.count % 2 != 0/ { print NR; exit }')"
map_branch_line="$(printf '%s\n' "$global_body" | awk '/binding\.type\.kind == TypeKind\.Map/ { print NR; exit }')"
failure_line="$(printf '%s\n' "$global_body" | awk '/InterpretFailure\.InvalidControlFlow/ { print NR; exit }')"
[[ "$guard_line" =~ ^[0-9]+$ && "$map_branch_line" =~ ^[0-9]+$ && "$failure_line" =~ ^[0-9]+$ ]] || {
    printf 'global map admission audit: missing odd-payload runtime guard\n' >&2
    exit 1
}
(( map_branch_line < guard_line && guard_line < failure_line )) || {
    printf 'global map admission audit: guard is not inside the map branch\n' >&2
    exit 1
}

rg -q 'module global map initializer must contain key/value pairs' "$verifier"
rg -q 'fails closed on malformed odd-length map payloads' "$docs"
rg -q 'rejects odd key/value payload lengths' "$ledger"
rg -q 'check_global_map_admission\.sh' "$plan"

printf 'global map admission audit: verifier and runtime reject odd key/value initializer payloads\n'
