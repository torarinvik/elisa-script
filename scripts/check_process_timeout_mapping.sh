#!/usr/bin/env bash

# Compiler-free audit for typed interpreter process timeout mapping.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
process_audit="$repo_root/scripts/check_process_capture.sh"
plan="$repo_root/IMPLEMENTATION_PLAN.md"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$interpreter" "$process_audit" "$plan" "$docs" "$ledger"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'process timeout audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q 'timed_out: mutable bool = false' "$interpreter"
rg -q 'waiter\.timed_out <- true' "$interpreter"

wait_block="$(awk '
    /^        def process_wait_next\(/ { active = 1 }
    active { print }
    active && /^        def / && !/^        def process_wait_next\(/ { exit }
' "$interpreter")"
[[ "$wait_block" == *'if waiter.polls >= INTERPRET_PROCESS_WAIT_MAX_POLLS:'* ]]
[[ "$wait_block" == *'waiter.timed_out <- true'* ]]
[[ "$wait_block" == *'process_wait_terminate(waiter)'* ]]
[[ "$wait_block" == *'waiter.failed <- true'* ]]

function_block() {
    local function_name="$1"
    awk -v function_name="$function_name" '
        $0 ~ "^        def " function_name "\\(" { active = 1 }
        active { print }
        active && /^        def / && $0 !~ "^        def " function_name "\\(" { exit }
    ' "$interpreter"
}

assert_timeout_mapping() {
    local function_name="$1"
    local block
    block="$(function_block "$function_name")"
    [[ -n "$block" ]]
    [[ "$block" == *'if waiter.timed_out:'* ]]
    [[ "$block" == *'machine.failure <- InterpretFailure.Time'* ]]
    if [[ "$function_name" != evaluate_run_process ]]; then
        [[ "$block" == *'if waiter.output_exceeded:'* ]]
        local output_line timeout_line
        output_line="$(printf '%s\n' "$block" | rg -n -m1 'if waiter\.output_exceeded:' | cut -d: -f1)"
        timeout_line="$(printf '%s\n' "$block" | rg -n -m1 'if waiter\.timed_out:' | cut -d: -f1)"
        (( output_line < timeout_line ))
    fi
}

assert_timeout_mapping evaluate_run_process
assert_timeout_mapping evaluate_capture_process_stream
assert_timeout_mapping evaluate_capture_process_result
assert_timeout_mapping evaluate_capture_process_stream_with_stdin

# Keep the existing deadlock/group-cleanup audit in the same compiler-free gate.
rg -q 'Q07:.*process capture' "$plan"
rg -q 'typed.*Time|InterpretFailure\.Time|timeout.*typed' "$docs" "$ledger"

printf 'process timeout audit: bounded wait exhaustion maps to typed Time after output-limit precedence and cleanup\n'
