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
    rg -q 'sampled and reactive, not an OS-enforced hard memory cap' "$wrapper"
    rg -q 'Go projects/structpy-tree/compiler/bin/elisac' "$wrapper"
    rg -Fq 'expected_compiler_path="/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/structpy-tree/compiler/bin/elisac"' "$wrapper"
    rg -Fq 'compiler_path="$canonical_compiler_dir/$compiler_name"' "$wrapper"
    rg -Fq 'if [ "$compiler_path" != "$expected_compiler_path" ] || [ ! -f "$compiler_path" ] || [ ! -x "$compiler_path" ]; then' "$wrapper"
    rg -q 'refusing symlinked compiler path' "$wrapper"
    rg -q 'process_group_rss_kb' "$wrapper"
    rg -q 'process_tree_pids "\$process_root_pid"' "$wrapper"
    rg -q 'tree_pid\[\$1\]' "$wrapper"
    rg -q 'setsid_path' "$wrapper"
    rg -q 'case "\$setsid_path" in' "$wrapper"
    rg -q '"\$setsid_path" "\$compiler"' "$wrapper"
    rg -q 'compiler_pgid' "$wrapper"
    rg -q 'validation_wrapper_pgid=' "$wrapper"
    rg -Fq '0|*[!0-9]*|"$validation_wrapper_pgid"' "$wrapper"
    rg -q 'process_group_rss_kb "\$compiler_pgid" "\$compiler_pid"' "$wrapper"
    rg -Fq 'process_table="$(ps -axo pid=,pgid=,rss= 2>/dev/null)" || return 1' "$wrapper"
    rg -Fq 'if (!scope_seen) exit 1' "$wrapper"
    rg -Fq 'process_table="$(ps -axo pgid=,stat= 2>/dev/null)" || return 0' "$wrapper"
    rg -Fq '$1 == group && $2 !~ /^Z/' "$wrapper"
    rg -q 'compiler_process_state' "$wrapper"
    rg -q 'reap_compiler_if_exited' "$wrapper"
    rg -Fq 'wait "$compiler_pid" 2>/dev/null || compiler_exit=$?' "$wrapper"
    rg -Fq 'kill -KILL -- "-$process_group_id"' "$wrapper"
    rg -Fq 'while :' "$wrapper"
    rg -q 'kill_process_tree "\$compiler_pid" "\$compiler_pgid"' "$wrapper"
    rg -q 'process_group_has_processes' "$wrapper"
    rg -q 'rss_measurement_failed' "$wrapper"
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
