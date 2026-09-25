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

for checker in "$script_dir"/check_*.sh; do
    [[ "$checker" == "$script_dir/check_validation_wrappers.sh" ]] && continue
    if rg -n 'IMPLEMENTATION_PLAN\.md|SCRIPT_TASKS\.md' "$checker"; then
        printf 'validation wrapper audit: checker must not depend on gitignored planning files: %s\n' "$checker" >&2
        exit 1
    fi
done

for wrapper in "$lowering" "$test_wrapper"; do
    rg -q 'ELISASCRIPT_VALIDATION_REAUTHORIZED:-0' "$wrapper"
    rg -q 'elisascript-validation\.disabled' "$wrapper"
    rg -q 'sampled and reactive, not an OS-enforced hard memory cap' "$wrapper"
    rg -q 'double-forked process' "$wrapper"
    rg -q 'Go projects/structpy-tree/compiler/bin/elisac' "$wrapper"
    rg -Fq 'expected_compiler_path="/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/structpy-tree/compiler/bin/elisac"' "$wrapper"
    rg -Fq 'compiler_path="$canonical_compiler_dir/$compiler_name"' "$wrapper"
    rg -Fq 'if [ "$compiler_path" != "$expected_compiler_path" ] || [ ! -f "$compiler_path" ] || [ ! -x "$compiler_path" ]; then' "$wrapper"
    rg -q 'refusing symlinked compiler path' "$wrapper"
    rg -q 'process_group_rss_kb' "$wrapper"
    rg -Fq 'rss_poll_interval_seconds=0.05' "$wrapper"
    rg -Fq 'sleep "$rss_poll_interval_seconds"' "$wrapper"
    rg -Fq 'rss_poll_interval_seconds=%s' "$wrapper"
    rg -Fq 'source_limit_bytes=65536' "$wrapper"
    rg -Fq 'head -c "$((source_limit_bytes + 1))" <"$source_file" >"$source_snapshot"' "$wrapper"
    rg -Fq 'wc -c <"$source_snapshot" 2>/dev/null' "$wrapper"
    rg -Fq 'if [ -L "$source_file" ]; then' "$wrapper"
    rg -Fq 'source_bytes=%s\nsource_limit_bytes=%s\n' "$wrapper"
    rg -Fq 'snapshot_path_hex=%s\n' "$wrapper"
    rg -Fq 'source_snapshot="$(mktemp "$source_parent/.elisascript-validation.XXXXXXXX")"' "$wrapper"
    rg -Fq 'rm -f "$source_snapshot"' "$wrapper"
    rg -q 'process_tree_pids "\$process_root_pid"' "$wrapper"
    rg -q 'tree_pid\[\$1\]' "$wrapper"
    rg -q 'setsid_path' "$wrapper"
    rg -q 'case "\$setsid_path" in' "$wrapper"
    case "$wrapper" in
        "$lowering")
            rg -Fq '"$setsid_path" "$compiler_path" -O0 -emit lowered "$source_snapshot"' "$wrapper"
            ;;
        "$test_wrapper")
            rg -Fq 'ELISASCRIPT_BOUNDED_TEST_RSS_GUARD=active "$setsid_path" "$compiler_path" -O0 -emit test "$source_snapshot"' "$wrapper"
            ;;
    esac
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
    rg -Uq 'rss_measurement_failed[^\n]*\n[[:space:]]+kill_process_tree_immediately "\$compiler_pid" "\$compiler_pgid"' "$wrapper"
    rg -Uq 'rss_guard[^\n]*\n[[:space:]]+kill_process_tree_immediately "\$compiler_pid" "\$compiler_pgid"' "$wrapper"
    rg -q 'kill -TERM -- "-\$process_group_id"' "$wrapper"
    rg -q 'kill_process_tree' "$wrapper"
    rg -q '^kill_process_tree_immediately\(\)' "$wrapper"
    rg -q 'kill_process_tree_immediately "\$compiler_pid" "\$compiler_pgid"' "$wrapper"
    rg -q 'validation_lease' "$wrapper"
    rg -Uq 'acquire_validation_lease\n\nif \[ -e "\$validation_disabled_file" \] \|\| \[ -L "\$validation_disabled_file" \]; then' "$wrapper"
    rg -Fq 'sh "$script_dir/validation_identity.sh"' "$wrapper"
    rg -q 'validation_compiler_binary_revision' "$wrapper"
    rg -q 'validation_compiler_binary_modified' "$wrapper"
    rg -q 'compiler_binary_revision=%s.*compiler_binary_modified=%s' "$wrapper"
    rg -Fq 'retained_log_budget_bytes=1073741824' "$wrapper"
    rg -q 'validation_log_bytes_used' "$wrapper"
    rg -q 'effective_log_limit_bytes' "$wrapper"
    rg -q 'mktemp "\$validation_log_dir/' "$wrapper"
    rg -q 'preserving bounded-run evidence' "$wrapper"
    rg -q 'numeric limits must not exceed 10 decimal digits' "$wrapper"
    if rg -Fq 'rm -f -- "$log_file"' "$wrapper"; then
        printf 'validation wrapper audit: evidence log must be retained in %s\n' "$wrapper" >&2
        exit 1
    fi
    if rg -Fq 'source_path=%s' "$wrapper"; then
        printf 'validation wrapper audit: source paths must be encoded in %s metadata\n' "$wrapper" >&2
        exit 1
    fi
    if rg -q 'Elisa-compiler|elisa-compiler/bin/elisac' "$wrapper"; then
        printf 'validation wrapper audit: forbidden main-worktree compiler reference in %s\n' "$wrapper" >&2
        exit 1
    fi
done

repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
for parity_test in "$repo_root"/test/script_parity/*_launcher_test.elisascript; do
    rg -q 'ELISASCRIPT_BOUNDED_TEST_RSS_GUARD' "$parity_test"
    rg -q 'assert rss_guard == "active"' "$parity_test"
done

rg -q 'emergency-stop latch' "$stopper"
rg -q 'owner\.start' "$stopper"
rg -q 'process_tree_snapshot' "$stopper"
rg -q 'process_group_for_pid' "$stopper"
rg -q 'kill -TERM -- "-\$process_group_id"' "$stopper"
rg -q 'kill -KILL -- "-\$process_group_id"' "$stopper"
printf 'validation wrapper audit: disabled gate, StructPy pin, bounded snapshots, sampled guards, evidence retention, lease, parity-fixture attestation, and owned stop path present\n'
