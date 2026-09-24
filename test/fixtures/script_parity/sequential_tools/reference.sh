#!/bin/sh
# Independent A07 contract: keep logs from completed steps and stop at failure.
set -u

prepare_stdout="$(/usr/bin/printf 'prepared\n')"
prepare_status=$?
failure_stdout=""
failure_status=0
dependent_started=false
dependent_stdout=""
dependent_status=0

if [ "$prepare_status" -eq 0 ]; then
    failure_stdout="$(/usr/bin/false)"
    failure_status=$?
fi

if [ "$prepare_status" -eq 0 ] && [ "$failure_status" -eq 0 ]; then
    dependent_started=true
    dependent_stdout="$(/usr/bin/printf 'unreachable\n')"
    dependent_status=$?
fi

prepare_failure=none
[ "$prepare_status" -eq 0 ] || prepare_failure=nonzero-exit
failure_kind=none
[ "$failure_status" -eq 0 ] || failure_kind=nonzero-exit
dependent_failure=none
[ "$dependent_status" -eq 0 ] || dependent_failure=nonzero-exit
graph_state=succeeded
if [ "$prepare_status" -ne 0 ] || [ "$failure_status" -ne 0 ]; then
    graph_state=failed
fi

printf 'graph=%s\n' "$graph_state"
printf 'step=prepare\nstarted=true\nstatus=%s\nfailure=%s\nstdout-begin\n' "$prepare_status" "$prepare_failure"
printf '%s\n' "$prepare_stdout"
printf 'stdout-end\nstderr-begin\nstderr-end\n'
printf 'step=fail\nstarted=%s\nstatus=%s\nfailure=%s\nstdout-begin\n' "$([ "$prepare_status" -eq 0 ] && printf true || printf false)" "$failure_status" "$failure_kind"
printf '%s' "$failure_stdout"
printf 'stdout-end\nstderr-begin\nstderr-end\n'
printf 'step=dependent\nstarted=%s\nstatus=%s\nfailure=%s\nstdout-begin\n' "$dependent_started" "$dependent_status" "$dependent_failure"
printf '%s' "$dependent_stdout"
printf 'stdout-end\nstderr-begin\nstderr-end\n'
