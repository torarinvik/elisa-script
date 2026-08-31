#!/bin/sh

# Lower one or more small Elisascript fixtures with the local StructPy compiler.
# This wrapper intentionally refuses installed or Elisa-core main-worktree
# binaries and enforces an RSS guard because a virtual-memory limit is not enough
# to protect the host from a runaway compiler.

set -u

default_compiler="$(CDPATH= cd -- "$(dirname -- "$0")/../../../Go projects/structpy-tree/compiler/bin" && pwd)/elisac"
compiler="${ELISA_LOCAL_COMPILER:-${ELISACORE_BIN:-$default_compiler}}"
case "$compiler" in
    *"/Go projects/structpy-tree/compiler/bin/elisac") ;;
    *)
        echo "run_bounded_lowering: refusing compiler outside Go projects/structpy-tree/compiler/bin/elisac" >&2
        exit 2
        ;;
esac

if [ "$#" -eq 0 ]; then
    echo "usage: run_bounded_lowering.sh SOURCE.elisascript [...]" >&2
    exit 2
fi

rss_limit_kb="${ELISASCRIPT_RSS_LIMIT_KB:-1800000}"
time_limit_seconds="${ELISASCRIPT_TIME_LIMIT_SECONDS:-120}"

for source_file in "$@"; do
    log_file="$(mktemp "${TMPDIR:-/tmp}/elisascript-lowering.XXXXXX")"
    "$compiler" -O0 -emit lowered "$source_file" >"$log_file" 2>&1 &
    compiler_pid=$!
    started_at="$(date +%s)"
    rss_guard=0
    timeout_guard=0
    compiler_exit=0

    while kill -0 "$compiler_pid" 2>/dev/null; do
        rss_kb="$(ps -o rss= -p "$compiler_pid" | awk '{print $1}')"
        if [ -n "$rss_kb" ] && [ "$rss_kb" -gt "$rss_limit_kb" ]; then
            rss_guard=1
            kill -TERM "$compiler_pid" 2>/dev/null || true
            sleep 1
            kill -KILL "$compiler_pid" 2>/dev/null || true
            break
        fi

        now="$(date +%s)"
        if [ "$((now - started_at))" -gt "$time_limit_seconds" ]; then
            timeout_guard=1
            kill -TERM "$compiler_pid" 2>/dev/null || true
            sleep 1
            kill -KILL "$compiler_pid" 2>/dev/null || true
            break
        fi
        sleep 1
    done

    wait "$compiler_pid" 2>/dev/null || compiler_exit=$?
    echo "$source_file exit=$compiler_exit rss_guard=$rss_guard timeout_guard=$timeout_guard"
    if [ "$compiler_exit" -ne 0 ] || [ "$rss_guard" -ne 0 ] || [ "$timeout_guard" -ne 0 ]; then
        tail -80 "$log_file"
        rm -f "$log_file"
        exit 1
    fi
    rm -f "$log_file"
done
