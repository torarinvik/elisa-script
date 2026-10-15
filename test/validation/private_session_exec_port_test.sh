#!/bin/sh

# Compare the checked-in Python helper with its ElisaScript port through a
# previously built public launcher. This does not compile either script.
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")/../../scripts" && pwd)"
port_script="$script_dir/private_session_exec.elisascript"
python_script="$script_dir/private_session_exec.py"
launcher="${ELISASCRIPT_PUBLIC_LAUNCHER:-}"
if [ -z "$launcher" ] || [ "${launcher#/}" = "$launcher" ] || [ ! -x "$launcher" ]; then
    echo "private-session port test: set ELISASCRIPT_PUBLIC_LAUNCHER to a qualified absolute launcher" >&2
    exit 2
fi
if [ ! -f "$port_script" ] || [ ! -f "$python_script" ]; then
    echo "private-session port test: missing helper source" >&2
    exit 2
fi

unset ELISASCRIPT_SESSION_READY_FILE ELISASCRIPT_SESSION_RELEASE_FILE || true
temporary_parent="${TMPDIR:-/tmp}"
test_root="$(mktemp -d "$temporary_parent/elisascript-session-port.XXXXXXXX")"
child_pid=""
watchdog_pid=""
ready_file=""
release_file=""

cleanup() {
    if [ -n "$watchdog_pid" ]; then
        kill -TERM "$watchdog_pid" 2>/dev/null || true
        wait "$watchdog_pid" 2>/dev/null || true
    fi
    if [ -n "$child_pid" ]; then
        kill -KILL "$child_pid" 2>/dev/null || true
        wait "$child_pid" 2>/dev/null || true
    fi
    rm -f "$test_root"/*.ready "$test_root"/*.release "$test_root"/*.release-target "$test_root"/*.stdout "$test_root"/*.stderr "$test_root/not-executable"
    rmdir "$test_root"/*.release-dir 2>/dev/null || true
    rmdir "$test_root" 2>/dev/null || true
}
trap cleanup 0 INT TERM

launch_helper() {
    helper_kind="$1"
    shift
    if [ -n "$ready_file" ] && [ -n "$release_file" ]; then
        if [ "$helper_kind" = python ]; then
            exec /usr/bin/env LC_ALL=C "ELISASCRIPT_SESSION_READY_FILE=$ready_file" "ELISASCRIPT_SESSION_RELEASE_FILE=$release_file" /usr/bin/python3 "$python_script" "$@"
        fi
        exec /usr/bin/env LC_ALL=C "ELISASCRIPT_SESSION_READY_FILE=$ready_file" "ELISASCRIPT_SESSION_RELEASE_FILE=$release_file" "$launcher" "$port_script" "$@"
    fi
    if [ -n "$ready_file" ]; then
        if [ "$helper_kind" = python ]; then
            exec /usr/bin/env LC_ALL=C "ELISASCRIPT_SESSION_READY_FILE=$ready_file" /usr/bin/python3 "$python_script" "$@"
        fi
        exec /usr/bin/env LC_ALL=C "ELISASCRIPT_SESSION_READY_FILE=$ready_file" "$launcher" "$port_script" "$@"
    fi
    if [ "$helper_kind" = python ]; then
        exec /usr/bin/env LC_ALL=C /usr/bin/python3 "$python_script" "$@"
    fi
    exec /usr/bin/env LC_ALL=C "$launcher" "$port_script" "$@"
}

run_simple() {
    helper_kind="$1"
    label="$2"
    shift 2
    stdout_file="$test_root/$label.stdout"
    stderr_file="$test_root/$label.stderr"
    launch_helper "$helper_kind" "$@" >"$stdout_file" 2>"$stderr_file" &
    child_pid=$!
    actual_status=0
    wait "$child_pid" || actual_status=$?
    child_pid=""
    actual_stdout="$(cat "$stdout_file")"
    actual_stderr="$(cat "$stderr_file")"
}

run_handshake_success() {
    helper_kind="$1"
    label="$2"
    ready_file="$test_root/$label.ready"
    release_file="$test_root/$label.release"
    stdout_file="$test_root/$label.stdout"
    stderr_file="$test_root/$label.stderr"
    probe='import os; print("pid={} sid={} pgid={} ready={} release={}".format(os.getpid(), os.getsid(0), os.getpgid(0), "ELISASCRIPT_SESSION_READY_FILE" in os.environ, "ELISASCRIPT_SESSION_RELEASE_FILE" in os.environ))'
    launch_helper "$helper_kind" /usr/bin/python3 -c "$probe" >"$stdout_file" 2>"$stderr_file" &
    child_pid=$!

    ready=0
    attempt=0
    while [ "$attempt" -lt 100 ]; do
        if [ -f "$ready_file" ]; then
            ready=1
            break
        fi
        if ! kill -0 "$child_pid" 2>/dev/null; then
            break
        fi
        sleep 0.05
        attempt=$((attempt + 1))
    done
    if [ "$ready" -ne 1 ]; then
        cat "$stderr_file" >&2
        echo "private-session port test: $helper_kind did not publish readiness" >&2
        return 1
    fi

    ready_pid="$(cat "$ready_file")"
    ready_mode="$(/usr/bin/stat -f '%Lp' "$ready_file")"
    group_pid="$(LC_ALL=C /bin/ps -o pgid= -p "$child_pid" | /usr/bin/tr -d '[:space:]')"
    if [ "$ready_mode" != 600 ]; then
        echo "private-session port test: $helper_kind ready-file mode is $ready_mode, expected 600" >&2
        return 1
    fi
    if [ "$ready_pid" != "$child_pid" ] || [ "$group_pid" != "$child_pid" ]; then
        echo "private-session port test: $helper_kind PID/PGID readiness mismatch" >&2
        return 1
    fi

    printf '%s\n' "$child_pid" >"$release_file"
    actual_status=0
    wait "$child_pid" || actual_status=$?
    child_pid=""
    actual_stdout="$(cat "$stdout_file")"
    actual_stderr="$(cat "$stderr_file")"
    expected_stdout="pid=$ready_pid sid=$ready_pid pgid=$ready_pid ready=False release=False"
    if [ "$actual_status" -ne 0 ] || [ "$actual_stdout" != "$expected_stdout" ] || [ -n "$actual_stderr" ]; then
        echo "private-session port test: $helper_kind released session output/status mismatch" >&2
        return 1
    fi
    ready_file=""
    release_file=""
    return 0
}

run_invalid_release() {
    helper_kind="$1"
    label="$2"
    ready_file="$test_root/$label.ready"
    release_file="$test_root/$label.release-dir"
    stdout_file="$test_root/$label.stdout"
    stderr_file="$test_root/$label.stderr"
    mkdir "$release_file"
    launch_helper "$helper_kind" /usr/bin/python3 -c 'pass' >"$stdout_file" 2>"$stderr_file" &
    child_pid=$!

    ready=0
    attempt=0
    while [ "$attempt" -lt 100 ]; do
        if [ -f "$ready_file" ]; then
            ready=1
            break
        fi
        if ! kill -0 "$child_pid" 2>/dev/null; then
            break
        fi
        sleep 0.05
        attempt=$((attempt + 1))
    done
    if [ "$ready" -ne 1 ]; then
        cat "$stderr_file" >&2
        echo "private-session port test: $helper_kind did not publish readiness for invalid release" >&2
        return 1
    fi

    expected_stderr="$(printf 'private_session_exec: session release was missing or invalid\n')"
    actual_status=0
    wait "$child_pid" || actual_status=$?
    child_pid=""
    actual_stdout="$(cat "$stdout_file")"
    actual_stderr="$(cat "$stderr_file")"
    if [ "$actual_status" -ne 125 ] || [ -n "$actual_stdout" ] || [ "$actual_stderr" != "$expected_stderr" ]; then
        echo "private-session port test: $helper_kind invalid-release status/streams mismatch" >&2
        return 1
    fi
    ready_file=""
    release_file=""
    return 0
}

run_symlink_release() {
    helper_kind="$1"
    label="$2"
    ready_file="$test_root/$label.ready"
    release_file="$test_root/$label.release"
    release_target="$test_root/$label.release-target"
    stdout_file="$test_root/$label.stdout"
    stderr_file="$test_root/$label.stderr"
    printf 'not a release token\n' >"$release_target"
    ln -s "$release_target" "$release_file"
    launch_helper "$helper_kind" /usr/bin/python3 -c 'pass' >"$stdout_file" 2>"$stderr_file" &
    child_pid=$!

    ready=0
    attempt=0
    while [ "$attempt" -lt 100 ]; do
        if [ -f "$ready_file" ]; then
            ready=1
            break
        fi
        if ! kill -0 "$child_pid" 2>/dev/null; then
            break
        fi
        sleep 0.05
        attempt=$((attempt + 1))
    done
    if [ "$ready" -ne 1 ]; then
        cat "$stderr_file" >&2
        echo "private-session port test: $helper_kind did not publish readiness for symlink release" >&2
        return 1
    fi

    expected_stderr="$(printf 'private_session_exec: session release was missing or invalid\n')"
    actual_status=0
    wait "$child_pid" || actual_status=$?
    child_pid=""
    actual_stdout="$(cat "$stdout_file")"
    actual_stderr="$(cat "$stderr_file")"
    if [ "$actual_status" -ne 125 ] || [ -n "$actual_stdout" ] || [ "$actual_stderr" != "$expected_stderr" ]; then
        echo "private-session port test: $helper_kind symlink-release status/streams mismatch" >&2
        return 1
    fi
    ready_file=""
    release_file=""
    return 0
}

run_release_timeout() {
    helper_kind="$1"
    label="$2"
    release_kind="$3"
    ready_file="$test_root/$label.ready"
    release_file="$test_root/$label.release"
    stdout_file="$test_root/$label.stdout"
    stderr_file="$test_root/$label.stderr"
    if [ "$release_kind" = wrong-token ]; then
        printf 'not a session token\n' >"$release_file"
    fi
    launch_helper "$helper_kind" /usr/bin/python3 -c 'pass' >"$stdout_file" 2>"$stderr_file" &
    child_pid=$!

    ready=0
    attempt=0
    while [ "$attempt" -lt 100 ]; do
        if [ -f "$ready_file" ]; then
            ready=1
            break
        fi
        if ! kill -0 "$child_pid" 2>/dev/null; then
            break
        fi
        sleep 0.05
        attempt=$((attempt + 1))
    done
    release_shape_ok=0
    if [ "$release_kind" = missing ] && [ ! -e "$release_file" ] && [ ! -L "$release_file" ]; then
        release_shape_ok=1
    elif [ "$release_kind" = wrong-token ] && [ -f "$release_file" ] && [ ! -L "$release_file" ]; then
        release_shape_ok=1
    fi
    if [ "$ready" -ne 1 ] || [ "$release_shape_ok" -ne 1 ]; then
        cat "$stderr_file" >&2
        echo "private-session port test: $helper_kind did not wait on the $release_kind release" >&2
        return 1
    fi

    # Both helpers use a ten-second monotonic deadline. Keep a separate
    # watchdog so a broken implementation cannot hang this shell test forever.
    /usr/bin/python3 -c 'import os, signal, sys, time; time.sleep(13); os.kill(int(sys.argv[1]), signal.SIGKILL)' "$child_pid" &
    watchdog_pid=$!
    expected_stderr="$(printf 'private_session_exec: session release was missing or invalid\n')"
    actual_status=0
    wait "$child_pid" || actual_status=$?
    child_pid=""
    kill -TERM "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
    watchdog_pid=""
    actual_stdout="$(cat "$stdout_file")"
    actual_stderr="$(cat "$stderr_file")"
    if [ "$actual_status" -ne 125 ] || [ -n "$actual_stdout" ] || [ "$actual_stderr" != "$expected_stderr" ]; then
        echo "private-session port test: $helper_kind $release_kind timeout mismatch" >&2
        return 1
    fi
    ready_file=""
    release_file=""
    return 0
}

expected_no_command="$(printf 'private_session_exec: expected a command\n')"
ready_file=""
release_file=""
run_simple python no-command-python
python_no_command_status="$actual_status"
python_no_command_stderr="$actual_stderr"
run_simple elisascript no-command-elisascript
if [ "$actual_status" -ne 2 ] || [ -n "$actual_stdout" ] || [ "$actual_stderr" != "$expected_no_command" ] || [ "$python_no_command_status" -ne 2 ] || [ "$python_no_command_stderr" != "$actual_stderr" ]; then
    echo "private-session port test: no-command result differs from Python" >&2
    exit 1
fi

# Exercise CPython-compatible repr quoting, newline escaping, and NBSP
# printability in the execvp diagnostic.
missing_command="$(printf '%s\n%s\302\240' "$test_root/missing-'\"-command" "next-line")"
ready_file=""
release_file=""
run_simple python missing-command-python "$missing_command"
python_missing_status="$actual_status"
python_missing_stderr="$actual_stderr"
run_simple elisascript missing-command-elisascript "$missing_command"
case "$actual_stderr" in
    *"[Errno 2]"*"No such file or directory"*) ;;
    *) echo "private-session port test: expected a Python ENOENT diagnostic" >&2; exit 1 ;;
esac
if [ "$actual_status" -ne 127 ] || [ -n "$actual_stdout" ] || [ "$actual_stderr" != "$python_missing_stderr" ] || [ "$python_missing_status" -ne 127 ]; then
    echo "private-session port test: exec failure differs from Python" >&2
    exit 1
fi

denied_command="$test_root/not-executable"
printf '#!/bin/sh\nexit 0\n' >"$denied_command"
chmod 600 "$denied_command"
ready_file=""
release_file=""
run_simple python denied-command-python "$denied_command"
python_denied_status="$actual_status"
python_denied_stderr="$actual_stderr"
run_simple elisascript denied-command-elisascript "$denied_command"
case "$actual_stderr" in
    *"[Errno 13]"*"Permission denied"*) ;;
    *) echo "private-session port test: expected a Python EACCES diagnostic" >&2; exit 1 ;;
esac
if [ "$actual_status" -ne 126 ] || [ -n "$actual_stdout" ] || [ "$actual_stderr" != "$python_denied_stderr" ] || [ "$python_denied_status" -ne 126 ]; then
    echo "private-session port test: permission-denied exec differs from Python" >&2
    exit 1
fi

ready_file="$test_root/incomplete.ready"
release_file=""
run_simple python incomplete-python /usr/bin/python3 -c 'pass'
python_incomplete_status="$actual_status"
python_incomplete_stderr="$actual_stderr"
ready_file="$test_root/incomplete-port.ready"
run_simple elisascript incomplete-elisascript /usr/bin/python3 -c 'pass'
expected_incomplete="$(printf 'private_session_exec: incomplete session handshake paths\n')"
if [ "$actual_status" -ne 1 ] || [ -n "$actual_stdout" ] || [ "$actual_stderr" != "$expected_incomplete" ] || [ "$python_incomplete_status" -ne 1 ] || [ "$python_incomplete_stderr" != "$actual_stderr" ]; then
    echo "private-session port test: incomplete handshake differs from Python" >&2
    exit 1
fi
ready_file=""

run_handshake_success python success-python
run_handshake_success elisascript success-elisascript
run_invalid_release python invalid-release-python
run_invalid_release elisascript invalid-release-elisascript
run_symlink_release python symlink-release-python
run_symlink_release elisascript symlink-release-elisascript
run_release_timeout python missing-release-timeout-python missing
run_release_timeout elisascript missing-release-timeout-elisascript missing
run_release_timeout python wrong-release-timeout-python wrong-token
run_release_timeout elisascript wrong-release-timeout-elisascript wrong-token

echo "private-session helper ports: matched status, streams, PID/PGID, ready-file mode, environment cleanup, valid/invalid release protocols, and missing/wrong-token timeouts"
