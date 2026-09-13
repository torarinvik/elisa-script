#!/usr/bin/env bash

# Compiler-free audit for process-group cleanup after the direct leader exits.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
differential="$repo_root/src/testing/differential.elisa"
runtime="$repo_root/src/runtime/runtime.elisa"
plan="$repo_root/IMPLEMENTATION_PLAN.md"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
tests="$repo_root/test/differential/elisascript_differential_test.elisa"

for required_file in "$interpreter" "$differential" "$runtime" "$plan" "$docs" "$ledger" "$tests"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'process descendant audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

function_block() {
    local source="$1"
    local function_name="$2"
    awk -v function_name="$function_name" '
        $0 ~ "^        def " function_name "\\(" { active = 1 }
        active { print }
        active && /^        def / && $0 !~ "^        def " function_name "\\(" { exit }
    ' "$source"
}

assert_group_cleanup_after_reap() {
    local source="$1"
    local function_name="$2"
    local block
    block="$(function_block "$source" "$function_name")"
    [[ -n "$block" ]]
    [[ "$block" == *'leader_reaped: mutable bool = false'* ]]
    [[ "$block" == *'leader_reaped <- true'* ]]
    [[ "$block" == *'process_wait_signal(-waiter.pid, INTERPRET_PROCESS_WAIT_KILL) if waiter.group_ready'* || "$block" == *'differential_signal_process(-pid, DIFFERENTIAL_SIGNAL_KILL) if group_ready'* ]]
    [[ "$block" == *'return if leader_reaped'* ]]
    local group_kill_line return_line
    group_kill_line="$(printf '%s\n' "$block" | rg -n -m1 'KILL.*if (waiter\.group_ready|group_ready)' | cut -d: -f1)"
    return_line="$(printf '%s\n' "$block" | rg -n -m1 'return if leader_reaped' | cut -d: -f1)"
    (( group_kill_line < return_line ))
}

assert_group_cleanup_after_reap "$interpreter" process_wait_terminate
assert_group_cleanup_after_reap "$differential" differential_terminate_process

rg -q 'EACCES: int = 13' "$runtime"
rg -q 'return true if errno\[0\] == DarwinErrno::EACCES' "$interpreter"
rg -q 'return true if errno\[0\] == DarwinErrno::EACCES' "$differential"

rg -q 'surviving descendants|leader exit.*group|leader.*group.*KILL' "$docs" "$ledger" "$plan"
rg -q 'differential_process_execution_reports_bounded_timeout' "$tests"
rg -q 'differential_process_timeout_owns_descendant_process_group' "$tests"

printf 'process descendant audit: leader reaping still forces private-group cleanup before termination returns\n'
