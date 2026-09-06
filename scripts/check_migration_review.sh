#!/usr/bin/env bash

# Compiler-free audit for the reviewed current-repository migration manifest.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
review_file="$repo_root/docs/migration-review-current.tsv"

if [[ ! -f "$review_file" ]]; then
    printf 'migration review audit: missing %s\n' "$review_file" >&2
    exit 1
fi

if ! rg -q '^path[[:space:]]+kind[[:space:]]+owner[[:space:]]+review_status[[:space:]]+entrypoint[[:space:]]+disposition[[:space:]]+risk[[:space:]]+notes$' "$review_file"; then
    printf 'migration review audit: invalid manifest header\n' >&2
    exit 1
fi

if ! awk -F '\t' '
    NR == 1 { next }
    NF != 8 { bad = 1; next }
    {
        if ($1 !~ /^\// || $2 != "shell" || $3 == "" || $3 == "unassigned") bad = 1
        if ($4 != "reviewed") bad = 1
        if ($5 != "direct executable") bad = 1
        if ($6 !~ /^(port|retain-external)$/) bad = 1
        if ($7 !~ /^(test|build|release)$/) bad = 1
        if ($8 == "") bad = 1
        paths[$1]++
        rows++
    }
    END {
        for (path in paths) if (paths[path] != 1) bad = 1
        if (rows != 20 || bad) exit 1
    }
' "$review_file"; then
    printf 'migration review audit: rows are incomplete, duplicated, unreviewed, or use an unapproved disposition\n' >&2
    exit 1
fi

for candidate in \
    check_differential_case.sh check_namespace_manifest.sh check_builtin_surface.sh \
    check_validation_wrappers.sh stop_bounded_validation.sh run_bounded_test.sh \
    inventory_project_roots.sh check_serialization_bounds.sh check_continuation_policy.sh \
    check_diagnostic_snapshot.sh inventory_signals.sh inventory_candidates.sh \
    check_migration_inventory.sh check_runtime_limits.sh check_builtin_registry.sh \
    check_streaming_file.sh check_path_line_contract.sh check_resource_policy.sh \
    run_bounded_lowering.sh check_effect_operation_metadata.sh; do
    if ! rg -q -F "/scripts/${candidate}" "$review_file"; then
        printf 'migration review audit: missing reviewed candidate %s\n' "$candidate" >&2
        exit 1
    fi
done

if ! rg -q '/scripts/(run_bounded_lowering|run_bounded_test|stop_bounded_validation|check_validation_wrappers)\.sh\tshell\telisascript-maintainers\treviewed\tdirect executable\tretain-external' "$review_file"; then
    printf 'migration review audit: safety wrappers are not explicitly retained\n' >&2
    exit 1
fi

bash -n "$script_dir/check_migration_review.sh"
printf 'migration review audit: 20 current candidates have reviewed ownership, disposition, and acceptance metadata\n'
