#!/bin/sh
# Independent A07 contract for explicit cwd/environment, retained logs, and fail-fast dependencies.
set -u

probe_cwd_stdout=""
probe_cwd_status=0
probe_env_stdout=""
probe_env_status=0
prepare_stdout=""
prepare_status=0
failure_stdout=""
failure_status=0
dependent_started=false
dependent_stdout=""
dependent_status=0

probe_cwd_stdout="$(cd / && /usr/bin/env -i /bin/pwd)"
probe_cwd_status=$?

probe_env_started=false
if [ "$probe_cwd_status" -eq 0 ]; then
    probe_env_started=true
    probe_env_stdout="$(cd / && /usr/bin/env -i TASK_STAGE=prepare /usr/bin/env)"
    probe_env_status=$?
fi

prepare_started=false
if [ "$probe_cwd_status" -eq 0 ] && [ "$probe_env_status" -eq 0 ]; then
    prepare_started=true
    prepare_stdout="$(cd / && /usr/bin/env -i TASK_STAGE=prepare /usr/bin/printf 'prepared\n')"
    prepare_status=$?
fi

failure_started=false
if [ "$probe_cwd_status" -eq 0 ] && [ "$probe_env_status" -eq 0 ] && [ "$prepare_status" -eq 0 ]; then
    failure_started=true
    failure_stdout="$(cd / && /usr/bin/env -i /usr/bin/false)"
    failure_status=$?
fi

if [ "$probe_cwd_status" -eq 0 ] && [ "$probe_env_status" -eq 0 ] && [ "$prepare_status" -eq 0 ] && [ "$failure_status" -eq 0 ]; then
    dependent_started=true
    dependent_stdout="$(cd / && /usr/bin/env -i /usr/bin/printf 'unreachable\n')"
    dependent_status=$?
fi

probe_cwd_failure=none
[ "$probe_cwd_status" -eq 0 ] || probe_cwd_failure=nonzero-exit
probe_env_failure=none
[ "$probe_env_status" -eq 0 ] || probe_env_failure=nonzero-exit
prepare_failure=none
[ "$prepare_status" -eq 0 ] || prepare_failure=nonzero-exit
failure_kind=none
[ "$failure_status" -eq 0 ] || failure_kind=nonzero-exit
dependent_failure=none
[ "$dependent_status" -eq 0 ] || dependent_failure=nonzero-exit
graph_state=succeeded
if [ "$probe_cwd_status" -ne 0 ] || [ "$probe_env_status" -ne 0 ] || [ "$prepare_status" -ne 0 ] || [ "$failure_status" -ne 0 ] || [ "$dependent_status" -ne 0 ]; then
    graph_state=failed
fi

printf 'graph=%s\n' "$graph_state"
printf 'step=probe-cwd\nstarted=true\nstatus=%s\nfailure=%s\nstdout-begin\n' "$probe_cwd_status" "$probe_cwd_failure"
printf '%s\n' "$probe_cwd_stdout"
printf 'stdout-end\nstderr-begin\nstderr-end\n'
printf 'step=probe-env\nstarted=%s\nstatus=%s\nfailure=%s\nstdout-begin\n' "$probe_env_started" "$probe_env_status" "$probe_env_failure"
printf '%s\n' "$probe_env_stdout"
printf 'stdout-end\nstderr-begin\nstderr-end\n'
printf 'step=prepare\nstarted=%s\nstatus=%s\nfailure=%s\nstdout-begin\n' "$prepare_started" "$prepare_status" "$prepare_failure"
printf '%s\n' "$prepare_stdout"
printf 'stdout-end\nstderr-begin\nstderr-end\n'
printf 'step=fail\nstarted=%s\nstatus=%s\nfailure=%s\nstdout-begin\n' "$failure_started" "$failure_status" "$failure_kind"
printf '%s' "$failure_stdout"
printf 'stdout-end\nstderr-begin\nstderr-end\n'
printf 'step=dependent\nstarted=%s\nstatus=%s\nfailure=%s\nstdout-begin\n' "$dependent_started" "$dependent_status" "$dependent_failure"
printf '%s' "$dependent_stdout"
printf 'stdout-end\nstderr-begin\nstderr-end\n'
