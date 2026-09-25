#!/usr/bin/env bash

# Compiler-free audit for the disabled-by-default validation wrappers.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
lowering="$script_dir/run_bounded_lowering.sh"
test_wrapper="$script_dir/run_bounded_test.sh"
stopper="$script_dir/stop_bounded_validation.sh"
snapshot_library="$script_dir/validation_process_snapshot.sh"

for wrapper in "$lowering" "$test_wrapper" "$stopper"; do
    if [[ ! -f "$wrapper" || ! -x "$wrapper" ]]; then
        printf 'validation wrapper audit: missing or non-executable %s\n' "$wrapper" >&2
        exit 1
    fi
done
if [[ ! -f "$snapshot_library" ]]; then
    printf 'validation wrapper audit: missing process snapshot library %s\n' "$snapshot_library" >&2
    exit 1
fi

sh -n "$lowering" "$test_wrapper" "$stopper" "$snapshot_library"

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
    rg -Fq 'if [ "$#" -ne 1 ]; then' "$wrapper"
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
    rg -Fq 'process_snapshot_row_limit=16384' "$wrapper"
    rg -Fq '. "$script_dir/validation_process_snapshot.sh"' "$wrapper"
    rg -Fq 'ps -axo pid=,ppid= 2>/dev/null; process_snapshot_ps_status=$?' "$wrapper"
    rg -Fq '__ELISASCRIPT_PS_STATUS__ %s\n' "$wrapper"
    rg -Fq 'validation_process_tree_pids_from_snapshot "$process_tree_root" "$process_snapshot_row_limit"' "$wrapper"
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
    rg -Fq 'process_table_ps_status=$?' "$wrapper"
    rg -Fq 'ps -axo pid=,ppid=,pgid=,rss=' "$wrapper"
    rg -Fq '__ELISASCRIPT_PS_STATUS__ %s\n' "$wrapper"
    rg -Fq 'head -n "$((process_snapshot_row_limit + 2))")" || return 1' "$wrapper"
    rg -Fq 'validation_process_group_rss_from_snapshot "$process_group_id" "$process_root_pid" "$process_snapshot_row_limit"' "$wrapper"
    rg -Fq 'ps -axo pgid=,stat= 2>/dev/null; process_table_ps_status=$?' "$wrapper"
    rg -Fq 'validation_process_group_has_live_members_from_snapshot "$process_group_id" "$process_snapshot_row_limit"' "$wrapper"
    rg -q 'compiler_process_state' "$wrapper"
    rg -q 'reap_compiler_if_exited' "$wrapper"
    rg -Fq 'if [ -n "$compiler_pgid" ] && process_group_has_processes "$compiler_pgid"; then' "$wrapper"
    rg -Fq 'Keep the session leader as an unreaped child while live' "$wrapper"
    rg -Uq 'if \[ -n "\$compiler_pgid" \] && process_group_has_processes "\$compiler_pgid"; then\n[[:space:]]+# Keep the session leader as an unreaped child while live\n[[:space:]]+# group members remain\.[^\n]*\n[[:space:]]+# through TERM/grace/KILL escalation instead of allowing\n[[:space:]]+# the numeric identifier to be recycled\.[^\n]*\n[[:space:]]+return 0\n[[:space:]]+fi\n[[:space:]]+# Never retain a PGID after releasing the unreaped leader:\n[[:space:]]+# a later cleanup trap must not mistake a recycled ID for us\.[^\n]*\n[[:space:]]+compiler_pgid=""\n[[:space:]]+wait "\$compiler_pid"' "$wrapper"
    rg -Fq 'if [ "$compiler_pgid" != "$compiler_pid" ]; then' "$wrapper"
    rg -Fq 'session leader PID does not own its process-group ID' "$wrapper"
    rg -Fq 'wait "$compiler_pid" 2>/dev/null || compiler_exit=$?' "$wrapper"
    rg -Fq 'kill -KILL -- "-$owned_group_id"' "$wrapper"
    rg -Fq 'validation_owned_process_group_id "$process_root_pid" "$process_group_id" "$validation_wrapper_pgid"' "$wrapper"
    rg -Fq 'while :' "$wrapper"
    rg -q 'kill_process_tree "\$compiler_pid" "\$compiler_pgid"' "$wrapper"
    rg -q 'process_group_has_processes' "$wrapper"
    rg -q 'rss_measurement_failed' "$wrapper"
    rg -Uq 'rss_measurement_failed[^\n]*\n[[:space:]]+kill_process_tree_immediately "\$compiler_pid" "\$compiler_pgid"' "$wrapper"
    rg -Uq 'rss_guard[^\n]*\n[[:space:]]+kill_process_tree_immediately "\$compiler_pid" "\$compiler_pgid"' "$wrapper"
    rg -q 'kill -TERM -- "-\$owned_group_id"' "$wrapper"
    rg -q 'kill_process_tree' "$wrapper"
    rg -q '^kill_process_tree_immediately\(\)' "$wrapper"
    rg -q 'kill_process_tree_immediately "\$compiler_pid" "\$compiler_pgid"' "$wrapper"
    if rg -Fq 'pgrep -P' "$wrapper"; then
        printf 'validation wrapper audit: process-tree snapshots must not recursively spawn pgrep in %s\n' "$wrapper" >&2
        exit 1
    fi
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

rg -Fq 'validation_process_tree_pids_from_snapshot()' "$snapshot_library"
rg -Fq 'validation_process_group_rss_from_snapshot()' "$snapshot_library"
rg -Fq 'validation_process_group_has_live_members_from_snapshot()' "$snapshot_library"
rg -Fq 'NF != 2' "$snapshot_library"
rg -Fq 'NF != 4' "$snapshot_library"
rg -Fq 'if (overflow || malformed || ps_failed || !status_seen || process_rows > row_limit || NR > row_limit + 1 || found) exit 0' "$snapshot_library"
rg -Fq 'exit 1' "$snapshot_library"
rg -Fq 'validation_owned_process_group_id()' "$snapshot_library"
rg -Fq '[ "$validation_group_candidate" = "$validation_group_root" ] || return 1' "$snapshot_library"
rg -Fq '[ "$validation_group_candidate" != "$validation_group_wrapper" ] || return 1' "$snapshot_library"
rg -Fq 'NR > row_limit + 1 { overflow = 1; exit }' "$snapshot_library"
rg -Fq 'if (overflow || malformed || ps_failed || !status_seen' "$snapshot_library"
rg -Fq 'if (!scope_seen) exit 1' "$snapshot_library"
rg -Fq 'queue[++tail] = child_pid' "$snapshot_library"

repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
snapshot_fixture="$repo_root/test/validation/process_snapshot_test.sh"
if [[ ! -f "$snapshot_fixture" ]]; then
    printf 'validation wrapper audit: missing process snapshot fixture %s\n' "$snapshot_fixture" >&2
    exit 1
fi
rg -Fq 'validation_process_tree_pids_from_snapshot 10 4' "$snapshot_fixture"
rg -Fq 'validation_process_group_rss_from_snapshot 10 10 8' "$snapshot_fixture"
rg -Fq 'failed liveness snapshot conservatively retains leader' "$snapshot_fixture"
rg -Fq 'oversized liveness snapshot conservatively retains leader' "$snapshot_fixture"
rg -Fq 'validation_owned_process_group_id 301 301 100' "$snapshot_fixture"
rg -Fq 'unsafe process group accepted' "$snapshot_fixture"
rg -Fq 'failed descendant process-table command' "$snapshot_fixture"
rg -Fq 'RSS row-limit overflow' "$snapshot_fixture"
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
