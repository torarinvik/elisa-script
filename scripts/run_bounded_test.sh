#!/bin/sh

# Run one or more small Elisascript test fixtures with the local StructPy
# compiler. This wrapper is deliberately separate from run_bounded_lowering.sh:
# executable test fixtures may run user code, so they need the same process-tree
# RSS guard before they are allowed on a development host.

set -u

# Validation is disabled by default after repeated runaway compiler chains. A
# caller must explicitly reauthorize a bounded run for this wrapper to launch
# any compiler process.
if [ "${ELISASCRIPT_VALIDATION_REAUTHORIZED:-0}" != "1" ]; then
    echo "run_bounded_test: validation disabled; set ELISASCRIPT_VALIDATION_REAUTHORIZED=1 to reauthorize" >&2
    exit 125
fi

default_compiler="$(CDPATH= cd -- "$(dirname -- "$0")/../../../Go projects/structpy-tree/compiler/bin" && pwd)/elisac"
compiler="${ELISA_LOCAL_COMPILER:-${ELISACORE_BIN:-$default_compiler}}"
case "$compiler" in
    *"/Go projects/structpy-tree/compiler/bin/elisac") ;;
    *)
        echo "run_bounded_test: refusing compiler outside Go projects/structpy-tree/compiler/bin/elisac" >&2
        exit 2
        ;;
esac

if [ "$#" -eq 0 ]; then
    echo "usage: run_bounded_test.sh SOURCE_TEST.elisascript [...]" >&2
    exit 2
fi

case "${ELISASCRIPT_RSS_LIMIT_KB:-524288}" in
    ''|*[!0-9]*)
        echo "run_bounded_test: ELISASCRIPT_RSS_LIMIT_KB must be a positive integer" >&2
        exit 2
        ;;
esac
case "${ELISASCRIPT_TIME_LIMIT_SECONDS:-120}" in
    ''|*[!0-9]*)
        echo "run_bounded_test: ELISASCRIPT_TIME_LIMIT_SECONDS must be a positive integer" >&2
        exit 2
        ;;
esac
if [ "${ELISASCRIPT_RSS_LIMIT_KB:-524288}" -eq 0 ] || [ "${ELISASCRIPT_TIME_LIMIT_SECONDS:-120}" -eq 0 ]; then
    echo "run_bounded_test: RSS and time limits must be positive" >&2
    exit 2
fi

process_tree_pids() {
    process_tree_root="$1"
    echo "$process_tree_root"
    for process_tree_child in $(pgrep -P "$process_tree_root" 2>/dev/null); do
        (process_tree_pids "$process_tree_child")
    done
}

process_tree_rss_kb() {
    process_tree_total=0
    for process_tree_pid in $(process_tree_pids "$1"); do
        process_tree_rss="$(ps -o rss= -p "$process_tree_pid" 2>/dev/null | awk '{print $1}')"
        if [ -n "$process_tree_rss" ]; then
            process_tree_total=$((process_tree_total + process_tree_rss))
        fi
    done
    echo "$process_tree_total"
}

kill_process_tree() {
    for process_tree_pid in $(process_tree_pids "$1"); do
        kill -TERM "$process_tree_pid" 2>/dev/null || true
    done
    sleep 1
    for process_tree_pid in $(process_tree_pids "$1"); do
        kill -KILL "$process_tree_pid" 2>/dev/null || true
    done
}

rss_limit_kb="${ELISASCRIPT_RSS_LIMIT_KB:-524288}"
time_limit_seconds="${ELISASCRIPT_TIME_LIMIT_SECONDS:-120}"
compiler_pid=""
log_file=""

cleanup_bounded_test() {
    if [ -n "$compiler_pid" ] && kill -0 "$compiler_pid" 2>/dev/null; then
        kill_process_tree "$compiler_pid"
    fi
    if [ -n "$log_file" ]; then
        rm -f -- "$log_file"
    fi
}

trap 'cleanup_bounded_test' 0
trap 'exit 130' INT TERM

for source_file in "$@"; do
    case "$source_file" in
        *.elisascript) ;;
        *)
            echo "run_bounded_test: refusing non-.elisascript input: $source_file" >&2
            exit 2
            ;;
    esac
    if [ ! -f "$source_file" ]; then
        echo "run_bounded_test: source file does not exist: $source_file" >&2
        exit 2
    fi
    log_file="$(mktemp "${TMPDIR:-/tmp}/elisascript-test.XXXXXX")"
    "$compiler" -O0 -emit test "$source_file" >"$log_file" 2>&1 &
    compiler_pid=$!
    started_at="$(date +%s)"
    rss_guard=0
    timeout_guard=0
    compiler_exit=0

    while kill -0 "$compiler_pid" 2>/dev/null; do
        rss_kb="$(process_tree_rss_kb "$compiler_pid")"
        if [ "$rss_kb" -gt "$rss_limit_kb" ]; then
            rss_guard=1
            kill_process_tree "$compiler_pid"
            break
        fi

        now="$(date +%s)"
        if [ "$((now - started_at))" -gt "$time_limit_seconds" ]; then
            timeout_guard=1
            kill_process_tree "$compiler_pid"
            break
        fi
        sleep 1
    done

    wait "$compiler_pid" 2>/dev/null || compiler_exit=$?
    # The PID is no longer owned after wait; clear it before any diagnostic or
    # exit path so the EXIT trap cannot mistake a reused PID for our compiler.
    compiler_pid=""
    echo "$source_file exit=$compiler_exit rss_guard=$rss_guard timeout_guard=$timeout_guard"
    if [ "$compiler_exit" -ne 0 ] || [ "$rss_guard" -ne 0 ] || [ "$timeout_guard" -ne 0 ]; then
        tail -80 "$log_file"
        rm -f -- "$log_file"
        exit 1
    fi
    rm -f -- "$log_file"
    log_file=""
    compiler_pid=""
done
