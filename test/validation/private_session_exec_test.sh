#!/bin/sh

# Exercise the checked-in private-session helper and its ready/release protocol
# without starting the compiler.
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")/../../scripts" && pwd)"
temporary_root="${TMPDIR:-/tmp}"
session_dir="$(mktemp -d "$temporary_root/elisascript-session-test.XXXXXXXX")"
ready_file="$session_dir/ready"
release_file="$session_dir/release"
output_file="$session_dir/output"
child_pid=""

cleanup() {
    if [ -n "$child_pid" ]; then
        kill -KILL "$child_pid" 2>/dev/null || true
        wait "$child_pid" 2>/dev/null || true
    fi
    rm -f "$ready_file" "$release_file" "$output_file"
    rmdir "$session_dir" 2>/dev/null || true
}
trap cleanup 0 INT TERM

ELISASCRIPT_SESSION_READY_FILE="$ready_file" \
ELISASCRIPT_SESSION_RELEASE_FILE="$release_file" \
    "$script_dir/private_session_exec.py" /usr/bin/python3 -c \
    'import os; print("pid={} sid={} pgid={}".format(os.getpid(), os.getsid(0), os.getpgid(0)))' \
    >"$output_file" 2>&1 &
child_pid=$!

session_ready=0
attempt=0
while [ "$attempt" -lt 100 ]; do
    if [ -f "$ready_file" ]; then
        session_ready=1
        break
    fi
    if ! kill -0 "$child_pid" 2>/dev/null; then
        break
    fi
    sleep 0.05
    attempt=$((attempt + 1))
done
if [ "$session_ready" -ne 1 ]; then
    cat "$output_file" >&2
    echo "private-session test: helper did not publish readiness" >&2
    exit 1
fi

ready_pid="$(cat "$ready_file")"
group_pid="$(LC_ALL=C /bin/ps -o pgid= -p "$child_pid" | tr -d '[:space:]')"
if [ "$ready_pid" != "$child_pid" ] || [ "$group_pid" != "$child_pid" ]; then
    echo "private-session test: readiness or process-group identity mismatch" >&2
    exit 1
fi

printf '%s\n' "$child_pid" >"$release_file"
wait "$child_pid"
child_pid=""
expected="pid=$ready_pid sid=$ready_pid pgid=$ready_pid"
actual="$(cat "$output_file")"
if [ "$actual" != "$expected" ]; then
    printf 'private-session test: expected <%s>, got <%s>\n' "$expected" "$actual" >&2
    exit 1
fi

echo "private-session helper: verified ready/release and PID=SID=PGID"
