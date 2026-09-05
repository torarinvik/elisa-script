#!/bin/sh

# Lower one or more small Elisascript fixtures with the local StructPy compiler.
# This wrapper intentionally refuses installed or Elisa-core main-worktree
# binaries and enforces an RSS guard because a virtual-memory limit is not enough
# to protect the host from a runaway compiler.

set -u
umask 077

validation_disabled_file="${TMPDIR:-/tmp}/elisascript-validation.disabled"

if [ -e "$validation_disabled_file" ]; then
    echo "run_bounded_lowering: validation emergency-stop latch is set; remove $validation_disabled_file only after review" >&2
    exit 125
fi

# Validation is disabled by default after repeated runaway compiler chains. A
# caller must explicitly reauthorize a bounded run for this wrapper to launch
# any compiler process.
if [ "${ELISASCRIPT_VALIDATION_REAUTHORIZED:-0}" != "1" ]; then
    echo "run_bounded_lowering: validation disabled; set ELISASCRIPT_VALIDATION_REAUTHORIZED=1 to reauthorize" >&2
    exit 125
fi

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

case "${ELISASCRIPT_RSS_LIMIT_KB:-524288}" in
    ''|*[!0-9]*)
        echo "run_bounded_lowering: ELISASCRIPT_RSS_LIMIT_KB must be a positive integer" >&2
        exit 2
        ;;
esac
case "${ELISASCRIPT_TIME_LIMIT_SECONDS:-120}" in
    ''|*[!0-9]*)
        echo "run_bounded_lowering: ELISASCRIPT_TIME_LIMIT_SECONDS must be a positive integer" >&2
        exit 2
        ;;
esac
case "${ELISASCRIPT_LOG_LIMIT_BYTES:-67108864}" in
    ''|*[!0-9]*)
        echo "run_bounded_lowering: ELISASCRIPT_LOG_LIMIT_BYTES must be a positive integer" >&2
        exit 2
        ;;
esac
if [ "${ELISASCRIPT_RSS_LIMIT_KB:-524288}" -eq 0 ] || [ "${ELISASCRIPT_TIME_LIMIT_SECONDS:-120}" -eq 0 ] || [ "${ELISASCRIPT_LOG_LIMIT_BYTES:-67108864}" -eq 0 ]; then
    echo "run_bounded_lowering: RSS, time, and log limits must be positive" >&2
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
    process_tree_snapshot="$(process_tree_pids "$1")"
    for process_tree_pid in $process_tree_snapshot; do
        kill -TERM "$process_tree_pid" 2>/dev/null || true
    done
    sleep 1
    for process_tree_pid in $process_tree_snapshot; do
        kill -KILL "$process_tree_pid" 2>/dev/null || true
    done
}

rss_limit_kb="${ELISASCRIPT_RSS_LIMIT_KB:-524288}"
time_limit_seconds="${ELISASCRIPT_TIME_LIMIT_SECONDS:-120}"
log_limit_bytes="${ELISASCRIPT_LOG_LIMIT_BYTES:-67108864}"
compiler_pid=""
log_file=""
validation_lease_dir="${TMPDIR:-/tmp}/elisascript-validation.lease"
validation_lease_pid="$$"
validation_lease_start=""
validation_lease_acquired=0

latch_validation_disabled() {
    latch_reason="$1"
    if ! printf '%s\n' "$latch_reason" >"$validation_disabled_file"; then
        echo "run_bounded_lowering: unable to persist emergency-stop latch" >&2
    fi
}

acquire_validation_lease() {
    validation_lease_start="$(ps -o lstart= -p "$validation_lease_pid" 2>/dev/null | sed 's/^[[:space:]]*//')"
    if [ -z "$validation_lease_start" ]; then
        echo "run_bounded_lowering: unable to identify this process for the validation lease" >&2
        exit 125
    fi

    if ! mkdir "$validation_lease_dir" 2>/dev/null; then
        if [ ! -f "$validation_lease_dir/owner.ready" ]; then
            echo "run_bounded_lowering: validation lease is being initialized; refusing concurrent work" >&2
            exit 125
        fi
        lease_owner_pid="$(sed -n '1p' "$validation_lease_dir/owner.pid" 2>/dev/null || true)"
        lease_owner_start="$(sed -n '1p' "$validation_lease_dir/owner.start" 2>/dev/null || true)"
        case "$lease_owner_pid" in
            ''|*[!0-9]*)
                echo "run_bounded_lowering: validation lease metadata is malformed; refusing to remove it" >&2
                exit 125
                ;;
        esac
        if kill -0 "$lease_owner_pid" 2>/dev/null; then
            lease_live_start="$(ps -o lstart= -p "$lease_owner_pid" 2>/dev/null | sed 's/^[[:space:]]*//')"
            lease_live_command="$(ps -o command= -p "$lease_owner_pid" 2>/dev/null | sed 's/^[[:space:]]*//')"
            case "$lease_live_command" in
                *run_bounded_lowering.sh*|*run_bounded_test.sh*) ;;
                *)
                    echo "run_bounded_lowering: live validation lease owner identity is not trusted; refusing concurrent work" >&2
                    exit 125
                    ;;
            esac
            if [ "$lease_owner_start" = "$lease_live_start" ]; then
                echo "run_bounded_lowering: another validation worker owns the lease (pid $lease_owner_pid)" >&2
            else
                echo "run_bounded_lowering: validation lease PID was reused; refusing to remove a live owner" >&2
            fi
            exit 125
        fi
        rm -f -- "$validation_lease_dir/owner.ready" "$validation_lease_dir/owner.pid" "$validation_lease_dir/owner.start"
        if ! rmdir "$validation_lease_dir" 2>/dev/null || ! mkdir "$validation_lease_dir" 2>/dev/null; then
            echo "run_bounded_lowering: stale validation lease could not be reclaimed safely" >&2
            exit 125
        fi
    fi

    if ! printf '%s\n' "$validation_lease_pid" >"$validation_lease_dir/owner.pid" \
        || ! printf '%s\n' "$validation_lease_start" >"$validation_lease_dir/owner.start" \
        || ! : >"$validation_lease_dir/owner.ready"; then
        rm -f -- "$validation_lease_dir/owner.ready" "$validation_lease_dir/owner.pid" "$validation_lease_dir/owner.start"
        rmdir "$validation_lease_dir" 2>/dev/null || true
        echo "run_bounded_lowering: unable to publish validation lease metadata" >&2
        exit 125
    fi
    validation_lease_acquired=1
}

release_validation_lease() {
    if [ "$validation_lease_acquired" -ne 1 ]; then
        return
    fi
    lease_current_start="$(ps -o lstart= -p "$validation_lease_pid" 2>/dev/null | sed 's/^[[:space:]]*//')"
    if [ "$lease_current_start" = "$validation_lease_start" ]; then
        rm -f -- "$validation_lease_dir/owner.ready" "$validation_lease_dir/owner.pid" "$validation_lease_dir/owner.start"
        rmdir "$validation_lease_dir" 2>/dev/null || true
    fi
    validation_lease_acquired=0
}

cleanup_bounded_lowering() {
    if [ -n "$compiler_pid" ] && kill -0 "$compiler_pid" 2>/dev/null; then
        kill_process_tree "$compiler_pid"
    fi
    if [ -n "$log_file" ]; then
        rm -f -- "$log_file"
    fi
    release_validation_lease
}

trap 'cleanup_bounded_lowering' 0
trap 'exit 130' INT TERM

acquire_validation_lease

for source_file in "$@"; do
    case "$source_file" in
        *.elisascript) ;;
        *)
            echo "run_bounded_lowering: refusing non-.elisascript input: $source_file" >&2
            exit 2
            ;;
    esac
    if [ ! -f "$source_file" ]; then
        echo "run_bounded_lowering: source file does not exist: $source_file" >&2
        exit 2
    fi
    log_file="$(mktemp "${TMPDIR:-/tmp}/elisascript-lowering.XXXXXX")"
    "$compiler" -O0 -emit lowered "$source_file" >"$log_file" 2>&1 &
    compiler_pid=$!
    started_at="$(date +%s)"
    rss_guard=0
    timeout_guard=0
    output_guard=0
    compiler_exit=0

    while kill -0 "$compiler_pid" 2>/dev/null; do
        rss_kb="$(process_tree_rss_kb "$compiler_pid")"
        if [ "$rss_kb" -gt "$rss_limit_kb" ]; then
            rss_guard=1
            latch_validation_disabled "run_bounded_lowering rss_guard pid=$compiler_pid rss_kb=$rss_kb limit_kb=$rss_limit_kb"
            kill_process_tree "$compiler_pid"
            break
        fi

        log_bytes="$(wc -c <"$log_file" | tr -d '[:space:]')"
        if [ "$log_bytes" -gt "$log_limit_bytes" ]; then
            output_guard=1
            latch_validation_disabled "run_bounded_lowering output_guard pid=$compiler_pid log_bytes=$log_bytes limit_bytes=$log_limit_bytes"
            kill_process_tree "$compiler_pid"
            break
        fi

        now="$(date +%s)"
        if [ "$((now - started_at))" -gt "$time_limit_seconds" ]; then
            timeout_guard=1
            latch_validation_disabled "run_bounded_lowering timeout_guard pid=$compiler_pid limit_seconds=$time_limit_seconds"
            kill_process_tree "$compiler_pid"
            break
        fi
        sleep 1
    done

    wait "$compiler_pid" 2>/dev/null || compiler_exit=$?
    # The PID is no longer owned after wait; clear it before any diagnostic or
    # exit path so the EXIT trap cannot mistake a reused PID for our compiler.
    compiler_pid=""
    echo "$source_file exit=$compiler_exit rss_guard=$rss_guard timeout_guard=$timeout_guard output_guard=$output_guard"
    if [ "$compiler_exit" -ne 0 ] || [ "$rss_guard" -ne 0 ] || [ "$timeout_guard" -ne 0 ] || [ "$output_guard" -ne 0 ]; then
        tail -80 "$log_file"
        rm -f -- "$log_file"
        exit 1
    fi
    rm -f -- "$log_file"
    log_file=""
    compiler_pid=""
done
