#!/usr/bin/env bash

# Compiler-free audit for the shell-free process-capture safety contract.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
differential="$repo_root/src/testing/differential.elisa"
process_runtime="$repo_root/src/runtime/process_posix.elisa"
source_file="$repo_root/src/ir/source_file.elisa"
tests="$repo_root/test/differential/elisascript_differential_test.elisa"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$interpreter" "$differential" "$process_runtime" "$source_file" "$tests" "$plan"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'process capture audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

# Keep process streams on seekable temporary files. This removes the classic
# stdout/stderr pipe-fill deadlock while retaining independent stream limits.
rg -q 'elisascript_posix_tmpfile\(\)' "$interpreter"
rg -q 'elisascript_posix_tmpfile\(\)' "$differential"
! rg -q 'elisascript_posix_pipe\(|\bpipe\(' "$interpreter" "$differential"

# Child setup is private-group based, and every parent-side failure path uses
# the shared terminate/reap edge before releasing stream handles.
rg -q 'def process_setpgid_parent\(' "$interpreter"
rg -q 'def process_wait_terminate\(' "$interpreter"
rg -q 'def differential_setpgid_parent\(' "$differential"
rg -q 'def differential_terminate_process\(' "$differential"
rg -q 'const module ProcessWait:' "$interpreter"
rg -q 'ProcessWait::NOHANG' "$interpreter"
rg -q 'ProcessWait::POLL_MICROSECONDS' "$interpreter"
rg -q 'ProcessWait::TERM_GRACE_POLLS' "$interpreter"
rg -q 'ProcessWait::MAX_POLLS' "$interpreter"
rg -q 'const module PosixRetry:' "$interpreter"
rg -q 'PosixRetry::EINTR_RETRIES' "$interpreter"
rg -q 'DIFFERENTIAL_TERM_GRACE_POLLS' "$differential"
rg -q 'process_wait_signal\(-waiter\.pid, ProcessWait::SIGNAL_TERM\)' "$interpreter"
rg -q 'process_wait_signal\(-waiter\.pid, ProcessWait::SIGNAL_KILL\)' "$interpreter"
rg -q 'differential_signal_process\(-pid, DIFFERENTIAL_SIGNAL_TERM\)' "$differential"
rg -q 'differential_signal_process\(-pid, DIFFERENTIAL_SIGNAL_KILL\)' "$differential"
rg -q 'process_wait_terminate\(waiter\)' "$interpreter"
rg -q 'differential_terminate_process\(pid, group_ready, status\)' "$differential"
rg -q 'elisascript_posix_waitpid_impl' "$process_runtime"

# Shared exact-size stdio helpers reject positive progress accompanied by the
# host error indicator, so a sticky stream error cannot be mistaken for a
# complete copy or capture.
rg -q 'def write_stream_fully\(' "$interpreter"
rg -q 'def read_stream_fully\(' "$interpreter"
rg -U -q 'amount == 0 or amount > remaining or ferror\(stream\) != 0' "$interpreter"
rg -U -q 'amount == 0 or amount > remaining or ferror\(writer\.stream\) != 0' "$interpreter"
rg -q 'def differential_write_stream_fully\(' "$differential"
rg -U -q 'amount == 0 or amount > remaining or ferror\(stream\) != 0' "$differential"
rg -q 'def differential_read_stream_fully\(' "$differential"
rg -q 'def elisascript_read_stream_fully\(' "$source_file"
rg -U -q 'amount == 0 or amount > remaining or ferror\(stream\) != 0' "$source_file"

# Both streams are checked independently before the next poll/sleep, and a
# timeout compares against the predecessor before incrementing its counter.
rg -q 'if waiter\.stdout_stream != null:' "$interpreter"
rg -q 'if waiter\.stderr_stream != null:' "$interpreter"
rg -q 'if stdout_size\.u64\(\) > invocation\.max_output_bytes or stderr_size\.u64\(\) > invocation\.max_output_bytes' "$differential"
rg -q 'if polls >= invocation\.timeout_steps - 1' "$differential"
rg -q 'if waiter\.polls >= ProcessWait::MAX_POLLS' "$interpreter"

# Output-limit and timeout outcomes have typed regression fixtures. These are
# metadata/static fixtures only; running a child process stays a gated action.
rg -q 'differential_process_capture_adapter_rejects_oversized_inputs' "$tests"
rg -q 'process capture exceeds output limit' "$tests"
rg -q 'process capture inputs exceed differential budget' "$tests"
rg -q 'process capture inputs are structurally invalid' "$tests"
rg -q 'timeout' "$differential"
rg -q 'Q07:.*process capture' "$plan"

printf 'process capture audit: temporary-file streams, paired limits, bounded polling, and group cleanup are present\n'
