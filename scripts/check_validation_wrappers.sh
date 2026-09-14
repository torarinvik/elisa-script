#!/usr/bin/env bash

# Compiler-free audit for the disabled-by-default validation wrappers.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
lowering="$script_dir/run_bounded_lowering.sh"
test_wrapper="$script_dir/run_bounded_test.sh"
stopper="$script_dir/stop_bounded_validation.sh"

for wrapper in "$lowering" "$test_wrapper" "$stopper"; do
    if [[ ! -f "$wrapper" || ! -x "$wrapper" ]]; then
        printf 'validation wrapper audit: missing or non-executable %s\n' "$wrapper" >&2
        exit 1
    fi
done

sh -n "$lowering" "$test_wrapper" "$stopper"

for wrapper in "$lowering" "$test_wrapper"; do
    rg -q 'ELISASCRIPT_VALIDATION_REAUTHORIZED:-0' "$wrapper"
    rg -q 'elisascript-validation\.disabled' "$wrapper"
    rg -q 'Go projects/structpy-tree/compiler/bin/elisac' "$wrapper"
    rg -q 'refusing symlinked compiler path' "$wrapper"
    rg -q 'process_group_rss_kb' "$wrapper"
    rg -q 'process_tree_pids "\$process_root_pid"' "$wrapper"
    rg -q 'tree_pid\[\$1\]' "$wrapper"
    rg -q 'setsid_path' "$wrapper"
    rg -q 'case "\$setsid_path" in' "$wrapper"
    rg -q '"\$setsid_path" "\$compiler"' "$wrapper"
    rg -q 'compiler_pgid' "$wrapper"
    rg -q 'validation_wrapper_pgid=' "$wrapper"
    rg -q 'process_group_rss_kb "\$compiler_pgid" "\$compiler_pid"' "$wrapper"
    rg -q 'kill -TERM -- "-\$process_group_id"' "$wrapper"
    rg -q 'kill_process_tree' "$wrapper"
    rg -q 'validation_lease' "$wrapper"
    if rg -q 'Elisa-compiler|elisa-compiler/bin/elisac' "$wrapper"; then
        printf 'validation wrapper audit: forbidden main-worktree compiler reference in %s\n' "$wrapper" >&2
        exit 1
    fi
done

rg -q 'emergency-stop latch' "$stopper"
rg -q 'owner\.start' "$stopper"
rg -q 'process_tree_snapshot' "$stopper"
rg -q 'process_group_for_pid' "$stopper"
rg -q 'kill -TERM -- "-\$process_group_id"' "$stopper"
rg -q 'kill -KILL -- "-\$process_group_id"' "$stopper"
printf 'validation wrapper audit: disabled gate, StructPy pin, RSS guard, lease, and owned stop path present\n'
