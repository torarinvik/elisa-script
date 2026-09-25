#!/bin/sh

# Lower one small Elisascript fixture per invocation with the local StructPy compiler.
# This wrapper intentionally refuses installed or Elisa-core main-worktree
# binaries and enforces an RSS guard because a virtual-memory limit is not enough
# to protect the host from a runaway compiler.
# The RSS guard is sampled and reactive, not an OS-enforced hard memory cap.

set -u
umask 077
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$script_dir/validation_process_snapshot.sh"

validation_disabled_file="${TMPDIR:-/tmp}/elisascript-validation.disabled"

if [ -e "$validation_disabled_file" ] || [ -L "$validation_disabled_file" ]; then
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

expected_compiler_path="/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/structpy-tree/compiler/bin/elisac"
expected_compiler_dir="$(CDPATH= cd -P -- "${expected_compiler_path%/*}" 2>/dev/null && pwd -P)"
if [ -z "$expected_compiler_dir" ]; then
    echo "run_bounded_lowering: unable to resolve the pinned StructPy compiler directory" >&2
    exit 2
fi
expected_compiler_path="$expected_compiler_dir/${expected_compiler_path##*/}"
compiler="${ELISA_LOCAL_COMPILER:-${ELISACORE_BIN:-$expected_compiler_path}}"
if [ -L "$compiler" ]; then
    echo "run_bounded_lowering: refusing symlinked compiler path" >&2
    exit 2
fi
case "$compiler" in
    */*) compiler_dir="${compiler%/*}"; compiler_name="${compiler##*/}" ;;
    *) compiler_dir=.; compiler_name="$compiler" ;;
esac
canonical_compiler_dir="$(CDPATH= cd -P -- "$compiler_dir" 2>/dev/null && pwd -P)"
compiler_path="$canonical_compiler_dir/$compiler_name"
if [ "$compiler_path" != "$expected_compiler_path" ] || [ ! -f "$compiler_path" ] || [ ! -x "$compiler_path" ]; then
    echo "run_bounded_lowering: refusing compiler other than the canonical local StructPy compiler: $expected_compiler_path" >&2
    exit 2
fi

setsid_path="${ELISASCRIPT_SETSID:-}"
if [ -z "$setsid_path" ]; then
    for setsid_candidate in /usr/bin/setsid /bin/setsid; do
        if [ -x "$setsid_candidate" ]; then
            setsid_path="$setsid_candidate"
            break
        fi
    done
fi
case "$setsid_path" in
    /*) [ -x "$setsid_path" ] || setsid_path="" ;;
    *) setsid_path="" ;;
esac
if [ -z "$setsid_path" ]; then
    echo "run_bounded_lowering: refusing to launch without an absolute executable setsid helper" >&2
    exit 125
fi

if [ "$#" -ne 1 ]; then
    echo "usage: run_bounded_lowering.sh SOURCE.elisascript" >&2
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
normalize_decimal() {
    normalized_decimal="$(printf '%s\n' "$1" | sed 's/^0*//')"
    printf '%s\n' "${normalized_decimal:-0}"
}
decimal_has_too_many_digits() {
    case "$1" in
        ???????????*) return 0 ;;
        *) return 1 ;;
    esac
}
rss_limit_kb="$(normalize_decimal "${ELISASCRIPT_RSS_LIMIT_KB:-524288}")"
time_limit_seconds="$(normalize_decimal "${ELISASCRIPT_TIME_LIMIT_SECONDS:-120}")"
log_limit_bytes="$(normalize_decimal "${ELISASCRIPT_LOG_LIMIT_BYTES:-67108864}")"
if [ "$rss_limit_kb" = "0" ] || [ "$time_limit_seconds" = "0" ] || [ "$log_limit_bytes" = "0" ]; then
    echo "run_bounded_lowering: RSS, time, and log limits must be positive" >&2
    exit 2
fi
if decimal_has_too_many_digits "$rss_limit_kb" || decimal_has_too_many_digits "$time_limit_seconds" || decimal_has_too_many_digits "$log_limit_bytes"; then
    echo "run_bounded_lowering: numeric limits must not exceed 10 decimal digits" >&2
    exit 2
fi
retained_log_budget_bytes=1073741824
metadata_reserve_bytes=16384
source_limit_bytes=65536
rss_poll_interval_seconds=0.05
process_snapshot_row_limit=16384
if [ "$log_limit_bytes" -gt "$retained_log_budget_bytes" ]; then
    echo "run_bounded_lowering: ELISASCRIPT_LOG_LIMIT_BYTES must not exceed the 1 GiB evidence budget" >&2
    exit 2
fi

process_tree_pids() {
    process_tree_root="$1"
    process_snapshot="$( { ps -axo pid=,ppid= 2>/dev/null; process_snapshot_ps_status=$?; printf '__ELISASCRIPT_PS_STATUS__ %s\n' "$process_snapshot_ps_status"; } | head -n "$((process_snapshot_row_limit + 2))")" || return 1
    printf '%s\n' "$process_snapshot" | validation_process_tree_pids_from_snapshot "$process_tree_root" "$process_snapshot_row_limit"
}

process_group_rss_kb() {
    process_group_id="$1"
    process_root_pid="$2"
    # Count the union of the isolated process group and descendants of the
    # compiler root. The group catches reparented children that retain their
    # group; the tree catches descendants that start a private session. The OR
    # predicate prevents counting ordinary same-group children twice. This is
    # still best-effort observation, not containment: a double-forked process
    # reparented after leaving this group can evade both snapshots.
    process_table="$( { ps -axo pid=,ppid=,pgid=,rss= 2>/dev/null; process_table_ps_status=$?; printf '__ELISASCRIPT_PS_STATUS__ %s\n' "$process_table_ps_status"; } | head -n "$((process_snapshot_row_limit + 2))")" || return 1
    printf '%s\n' "$process_table" | validation_process_group_rss_from_snapshot "$process_group_id" "$process_root_pid" "$process_snapshot_row_limit"
}

process_group_for_pid() {
    ps -o pgid= -p "$1" 2>/dev/null | tr -d '[:space:]'
}

process_group_has_processes() {
    process_group_id="$1"
    process_table="$( { ps -axo pgid=,stat= 2>/dev/null; process_table_ps_status=$?; printf '__ELISASCRIPT_PS_STATUS__ %s\n' "$process_table_ps_status"; } | head -n "$((process_snapshot_row_limit + 2))")" || return 0
    printf '%s\n' "$process_table" | validation_process_group_has_live_members_from_snapshot "$process_group_id" "$process_snapshot_row_limit"
}

compiler_process_state() {
    process_id="$1"
    process_table="$( { ps -axo pid=,stat= 2>/dev/null; process_table_ps_status=$?; printf '__ELISASCRIPT_PS_STATUS__ %s\n' "$process_table_ps_status"; } | head -n "$((process_snapshot_row_limit + 2))")" || { printf 'unknown\n'; return 0; }
    printf '%s\n' "$process_table" | validation_process_state_from_snapshot "$process_id" "$process_snapshot_row_limit"
}

reap_compiler_if_exited() {
    if [ -n "$compiler_pid" ]; then
        compiler_state="$(compiler_process_state "$compiler_pid" 2>/dev/null || printf 'unknown\n')"
        case "$compiler_state" in
            absent|zombie)
                if [ -n "$compiler_pgid" ] && process_group_has_processes "$compiler_pgid"; then
                    # Keep the session leader as an unreaped child while live
                    # group members remain. This preserves the PGID's identity
                    # through TERM/grace/KILL escalation instead of allowing
                    # the numeric identifier to be recycled.
                    return 0
                fi
                # Never retain a PGID after releasing the unreaped leader:
                # a later cleanup trap must not mistake a recycled ID for us.
                compiler_pgid=""
                wait "$compiler_pid" 2>/dev/null || compiler_exit=$?
                compiler_pid=""
                ;;
        esac
    fi
}

kill_process_tree() {
    process_root_pid="$1"
    process_group_id="$2"
    # In normal operation the direct setsid child remains unreaped until its
    # live process group is empty, which reserves the PGID through escalation.
    # This still relies on portable numeric signals, not an OS-enforced memory
    # or descendant-containment boundary.
    process_tree_snapshot=""
    if [ -n "$process_root_pid" ]; then
        process_tree_snapshot="$(process_tree_pids "$process_root_pid" 2>/dev/null)" || process_tree_snapshot=""
    fi
    case "$process_group_id" in
        ''|0|*[!0-9]*) process_group_id="$(process_group_for_pid "$process_root_pid")" ;;
    esac
    owned_group_id="$(validation_owned_process_group_id "$process_root_pid" "$process_group_id" "$validation_wrapper_pgid" 2>/dev/null || true)"
    if [ -n "$owned_group_id" ]; then
        kill -TERM -- "-$owned_group_id" 2>/dev/null || true
    fi
    for process_tree_pid in $process_tree_snapshot; do
        kill -TERM "$process_tree_pid" 2>/dev/null || true
    done
    sleep 1
    for process_tree_pid in $process_tree_snapshot; do
        kill -KILL "$process_tree_pid" 2>/dev/null || true
    done
    owned_group_id="$(validation_owned_process_group_id "$process_root_pid" "$process_group_id" "$validation_wrapper_pgid" 2>/dev/null || true)"
    if [ -n "$owned_group_id" ]; then
        kill -KILL -- "-$owned_group_id" 2>/dev/null || true
    fi
}

kill_process_tree_immediately() {
    process_root_pid="$1"
    process_group_id="$2"
    process_tree_snapshot=""
    if [ -n "$process_root_pid" ]; then
        process_tree_snapshot="$(process_tree_pids "$process_root_pid" 2>/dev/null)" || process_tree_snapshot=""
    fi
    case "$process_group_id" in
        ''|0|*[!0-9]*) process_group_id="$(process_group_for_pid "$process_root_pid")" ;;
    esac
    owned_group_id="$(validation_owned_process_group_id "$process_root_pid" "$process_group_id" "$validation_wrapper_pgid" 2>/dev/null || true)"
    if [ -n "$owned_group_id" ]; then
        kill -KILL -- "-$owned_group_id" 2>/dev/null || true
    fi
    for process_tree_pid in $process_tree_snapshot; do
        kill -KILL "$process_tree_pid" 2>/dev/null || true
    done
}

compiler_pid=""
compiler_pgid=""
source_snapshot=""
validation_wrapper_pgid="$(process_group_for_pid "$$")"
case "$validation_wrapper_pgid" in
    ''|*[!0-9]*)
        echo "run_bounded_lowering: unable to identify wrapper process group" >&2
        exit 125
        ;;
esac
log_file=""
metadata_file=""
metadata_finalized=0
validation_lease_dir="${TMPDIR:-/tmp}/elisascript-validation.lease"
validation_lease_pid="$$"
validation_lease_start=""
validation_lease_acquired=0

latch_validation_disabled() {
    latch_reason="$1"
    if [ -L "$validation_disabled_file" ] || { [ -e "$validation_disabled_file" ] && [ ! -d "$validation_disabled_file" ]; }; then
        echo "run_bounded_lowering: emergency-stop latch path is not a private directory" >&2
        return 1
    fi
    if [ ! -d "$validation_disabled_file" ] && ! mkdir "$validation_disabled_file" 2>/dev/null; then
        echo "run_bounded_lowering: unable to create emergency-stop latch" >&2
        return 1
    fi
    if [ ! -d "$validation_disabled_file" ]; then
        echo "run_bounded_lowering: emergency-stop latch path is not a directory" >&2
        return 1
    fi
    if [ ! -e "$validation_disabled_file/reason" ]; then
        (set -C; printf '%s\n' "$latch_reason" >"$validation_disabled_file/reason") 2>/dev/null || true
    fi
    return 0
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
    if [ -n "$compiler_pid" ] || [ -n "$compiler_pgid" ]; then
        if { [ -n "$compiler_pid" ] && kill -0 "$compiler_pid" 2>/dev/null; } || { [ -n "$compiler_pgid" ] && process_group_has_processes "$compiler_pgid"; }; then
            kill_process_tree "$compiler_pid" "$compiler_pgid"
        fi
    fi
    if [ -n "$source_snapshot" ]; then
        rm -f "$source_snapshot" 2>/dev/null || true
        source_snapshot=""
    fi
    if [ -n "$log_file" ] && [ "$metadata_finalized" -eq 0 ]; then
        if [ -n "$metadata_file" ]; then
            printf '%s\n' 'run_status=incomplete_or_interrupted' >>"$metadata_file" 2>/dev/null || true
        fi
        echo "run_bounded_lowering: preserving bounded-run evidence log=$log_file metadata=${metadata_file:-unavailable}" >&2
    fi
    release_validation_lease
}

trap 'cleanup_bounded_lowering' 0
trap 'exit 130' INT TERM

acquire_validation_lease

# Close the startup race with stop_bounded_validation.sh: if it sets the
# emergency latch before this lease becomes visible, the post-lease check must
# observe it before compiler identity work or a launch can proceed. If the stop
# arrives after this check, the stopper can verify and terminate this lease.
if [ -e "$validation_disabled_file" ] || [ -L "$validation_disabled_file" ]; then
    echo "run_bounded_lowering: validation emergency-stop latch is set; refusing to launch" >&2
    exit 125
fi

validation_mode="lowered"
if ! validation_identity_output="$(ELISA_LOCAL_COMPILER="$compiler_path" ELISASCRIPT_VALIDATION_OPT_LEVEL=O0 ELISASCRIPT_VALIDATION_TARGET=native ELISASCRIPT_VALIDATION_MODE="$validation_mode" sh "$script_dir/validation_identity.sh")"; then
    echo "run_bounded_lowering: unable to establish compiler/configuration identity; refusing to launch" >&2
    exit 125
fi
validation_identity_field() {
    printf '%s\n' "$validation_identity_output" | sed -n "s/^$1=//p"
}
validation_log_dir="$(validation_identity_field log_dir)"
validation_configuration_key="$(validation_identity_field configuration_key)"
validation_compiler_revision="$(validation_identity_field compiler_revision)"
validation_compiler_binary_revision="$(validation_identity_field compiler_binary_revision)"
validation_compiler_binary_modified="$(validation_identity_field compiler_binary_modified)"
validation_compiler_sha256="$(validation_identity_field compiler_sha256)"
if [ -z "$validation_log_dir" ] || [ -z "$validation_configuration_key" ] || [ -z "$validation_compiler_revision" ] || [ -z "$validation_compiler_binary_revision" ] || [ "$validation_compiler_binary_revision" != "$validation_compiler_revision" ] || [ "$validation_compiler_binary_modified" != "false" ] || [ -z "$validation_compiler_sha256" ]; then
    echo "run_bounded_lowering: compiler/configuration identity is incomplete; refusing to launch" >&2
    exit 125
fi
case "$validation_configuration_key:$validation_compiler_revision:$validation_compiler_binary_revision:$validation_compiler_sha256" in
    *[!0-9a-f:]*)
        echo "run_bounded_lowering: compiler/configuration identity is malformed; refusing to launch" >&2
        exit 125
        ;;
esac
case "$validation_log_dir" in
    /*) ;;
    *) validation_log_dir="$PWD/$validation_log_dir" ;;
esac
if [ -L "$validation_log_dir" ] || [ ! -d "$validation_log_dir" ]; then
    echo "run_bounded_lowering: identity log directory is missing or symlinked; refusing to launch" >&2
    exit 125
fi
if ! validation_log_dir="$(CDPATH= cd -P -- "$validation_log_dir" 2>/dev/null && pwd -P)"; then
    echo "run_bounded_lowering: unable to resolve identity log directory; refusing to launch" >&2
    exit 125
fi

validation_log_bytes_used() {
    validation_log_usage="$(du -sk "$validation_log_dir" 2>/dev/null)" || return 1
    validation_log_kb="$(printf '%s\n' "$validation_log_usage" | awk 'NR == 1 { print $1 }')"
    case "$validation_log_kb" in
        ''|*[!0-9]*) return 1 ;;
    esac
    printf '%s\n' "$((validation_log_kb * 1024))"
}

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
    if [ -L "$source_file" ]; then
        echo "run_bounded_lowering: refusing symlinked source file: $source_file" >&2
        exit 2
    fi
    case "$source_file" in
        */*)
            source_parent="${source_file%/*}"
            if [ -z "$source_parent" ]; then
                source_parent="/"
            fi
            ;;
        *)
            source_parent="."
            ;;
    esac
    source_snapshot="$(mktemp "$source_parent/.elisascript-validation.XXXXXXXX")" || {
        echo "run_bounded_lowering: unable to create a private sibling source snapshot; refusing to launch" >&2
        exit 125
    }
    if ! head -c "$((source_limit_bytes + 1))" <"$source_file" >"$source_snapshot"; then
        echo "run_bounded_lowering: unable to capture bounded source bytes; refusing to launch" >&2
        exit 125
    fi
    if ! source_bytes_raw="$(wc -c <"$source_snapshot" 2>/dev/null)"; then
        echo "run_bounded_lowering: unable to measure captured source size; refusing to launch" >&2
        exit 125
    fi
    source_bytes="$(printf '%s\n' "$source_bytes_raw" | tr -d '[:space:]')"
    case "$source_bytes" in
        ''|*[!0-9]*)
            echo "run_bounded_lowering: captured source-size measurement was invalid; refusing to launch" >&2
            exit 125
            ;;
    esac
    if [ "$source_bytes" -gt "$source_limit_bytes" ]; then
        echo "run_bounded_lowering: captured source is $source_bytes bytes, above the $source_limit_bytes-byte fixture limit: $source_file" >&2
        exit 2
    fi
    retained_log_bytes="$(validation_log_bytes_used)" || {
        echo "run_bounded_lowering: unable to measure retained validation evidence; refusing to launch" >&2
        exit 125
    }
    if [ "$retained_log_bytes" -ge "$retained_log_budget_bytes" ]; then
        echo "run_bounded_lowering: identity log budget is exhausted; remove reviewed old evidence before retrying" >&2
        exit 125
    fi
    available_log_bytes="$((retained_log_budget_bytes - retained_log_bytes - metadata_reserve_bytes))"
    if [ "$available_log_bytes" -le 0 ]; then
        echo "run_bounded_lowering: identity log budget has no room for a bounded run manifest; refusing to launch" >&2
        exit 125
    fi
    effective_log_limit_bytes="$log_limit_bytes"
    if [ "$effective_log_limit_bytes" -gt "$available_log_bytes" ]; then
        effective_log_limit_bytes="$available_log_bytes"
    fi
    started_at="$(date +%s)"
    metadata_finalized=0
    log_file="$(mktemp "$validation_log_dir/lowering.XXXXXX")" || {
        echo "run_bounded_lowering: unable to create identity-keyed compiler log; refusing to launch" >&2
        exit 125
    }
    metadata_file="$log_file.meta"
    source_path_hex="$(printf '%s' "$source_file" | od -An -tx1 | tr -d '[:space:]')"
    snapshot_path_hex="$(printf '%s' "$source_snapshot" | od -An -tx1 | tr -d '[:space:]')"
    working_directory_hex="$(pwd -P | od -An -tx1 | tr -d '[:space:]')"
    if ! (set -C; {
        printf 'compiler_path=%s\ncompiler_revision=%s\ncompiler_binary_revision=%s\ncompiler_binary_modified=%s\ncompiler_sha256=%s\n' "$compiler_path" "$validation_compiler_revision" "$validation_compiler_binary_revision" "$validation_compiler_binary_modified" "$validation_compiler_sha256"
        printf 'configuration_key=%s\noptimization=O0\ntarget=native\nmode=lowered\nlog_dir_hex=%s\n' "$validation_configuration_key" "$(printf '%s' "$validation_log_dir" | od -An -tx1 | tr -d '[:space:]')"
        printf 'wrapper=run_bounded_lowering\nsource_path_hex=%s\n' "$source_path_hex"
        printf 'snapshot_path_hex=%s\n' "$snapshot_path_hex"
        printf 'working_directory_hex=%s\nstarted_epoch=%s\n' "$working_directory_hex" "$started_at"
        printf 'source_bytes=%s\nsource_limit_bytes=%s\nrss_limit_kb=%s\nrss_poll_interval_seconds=%s\ntime_limit_seconds=%s\nconfigured_log_limit_bytes=%s\neffective_log_limit_bytes=%s\nretained_log_budget_bytes=%s\n' "$source_bytes" "$source_limit_bytes" "$rss_limit_kb" "$rss_poll_interval_seconds" "$time_limit_seconds" "$log_limit_bytes" "$effective_log_limit_bytes" "$retained_log_budget_bytes"
        printf 'argv0=%s\nargv1=-O0\nargv2=-emit\nargv3=lowered\nargv4_hex=%s\n' "$compiler_path" "$snapshot_path_hex"
    } >"$metadata_file") 2>/dev/null; then
        echo "run_bounded_lowering: unable to create run metadata; refusing to launch" >&2
        exit 125
    fi
    metadata_finalized=0
    "$setsid_path" "$compiler_path" -O0 -emit lowered "$source_snapshot" >"$log_file" 2>&1 &
    compiler_pid=$!
    compiler_pgid="$(process_group_for_pid "$compiler_pid")"
    if ! {
        printf 'compiler_pid=%s\ncompiler_pgid=%s\n' "$compiler_pid" "$compiler_pgid"
    } >>"$metadata_file"; then
        echo "run_bounded_lowering: unable to record compiler ownership; stopping it" >&2
        kill_process_tree "$compiler_pid" "$compiler_pgid"
        wait "$compiler_pid" 2>/dev/null || true
        compiler_pid=""
        compiler_pgid=""
        exit 125
    fi
    case "$compiler_pgid" in
        ''|0|*[!0-9]*|"$validation_wrapper_pgid")
            echo "run_bounded_lowering: compiler was not isolated in a private process group" >&2
            kill_process_tree "$compiler_pid" "$compiler_pgid"
            exit 125
            ;;
    esac
    if [ "$compiler_pgid" != "$compiler_pid" ]; then
        echo "run_bounded_lowering: session leader PID does not own its process-group ID" >&2
        kill_process_tree "$compiler_pid" "$compiler_pgid"
        exit 125
    fi
    rss_guard=0
    timeout_guard=0
    output_guard=0
    peak_rss_kb=0
    rss_sample_count=0
    compiler_exit=0

    while :; do
        reap_compiler_if_exited
        if [ -z "$compiler_pid" ] && ! process_group_has_processes "$compiler_pgid"; then
            break
        fi
        if ! rss_kb="$(process_group_rss_kb "$compiler_pgid" "$compiler_pid")"; then
            # The process can exit between the state check and RSS snapshot.
            # Recheck before treating a vanished, empty group as a measurement
            # failure; a failed ps while work remains still fails closed below.
            reap_compiler_if_exited
            if [ -z "$compiler_pid" ] && ! process_group_has_processes "$compiler_pgid"; then
                break
            fi
            rss_guard=1
            if ! latch_validation_disabled "run_bounded_lowering rss_measurement_failed pid=$compiler_pid pgid=$compiler_pgid"; then
                kill_process_tree_immediately "$compiler_pid" "$compiler_pgid"
                exit 125
            fi
            kill_process_tree_immediately "$compiler_pid" "$compiler_pgid"
            break
        fi
        rss_sample_count=$((rss_sample_count + 1))
        if [ "$rss_kb" -gt "$peak_rss_kb" ]; then
            peak_rss_kb="$rss_kb"
        fi
        if [ "$rss_kb" -gt "$rss_limit_kb" ]; then
            rss_guard=1
            if ! latch_validation_disabled "run_bounded_lowering rss_guard pid=$compiler_pid rss_kb=$rss_kb limit_kb=$rss_limit_kb"; then
                kill_process_tree_immediately "$compiler_pid" "$compiler_pgid"
                exit 125
            fi
            kill_process_tree_immediately "$compiler_pid" "$compiler_pgid"
            break
        fi

        # Output size is sampled like RSS: this detects and stops observed
        # excess, but a fast writer can overshoot between samples.
        log_bytes="$(wc -c <"$log_file" | tr -d '[:space:]')"
        case "$log_bytes" in
            ''|*[!0-9]*)
                output_guard=1
                if ! latch_validation_disabled "run_bounded_lowering log_measurement_failed pid=$compiler_pid"; then
                    kill_process_tree "$compiler_pid" "$compiler_pgid"
                    exit 125
                fi
                kill_process_tree "$compiler_pid" "$compiler_pgid"
                break
                ;;
        esac
        if [ "$log_bytes" -gt "$effective_log_limit_bytes" ]; then
            output_guard=1
            if ! latch_validation_disabled "run_bounded_lowering output_guard pid=$compiler_pid log_bytes=$log_bytes limit_bytes=$effective_log_limit_bytes"; then
                kill_process_tree "$compiler_pid" "$compiler_pgid"
                exit 125
            fi
            kill_process_tree "$compiler_pid" "$compiler_pgid"
            break
        fi

        now="$(date +%s)"
        if [ "$((now - started_at))" -gt "$time_limit_seconds" ]; then
            timeout_guard=1
            if ! latch_validation_disabled "run_bounded_lowering timeout_guard pid=$compiler_pid limit_seconds=$time_limit_seconds"; then
                kill_process_tree "$compiler_pid" "$compiler_pgid"
                exit 125
            fi
            kill_process_tree "$compiler_pid" "$compiler_pgid"
            break
        fi
        # Sample at 20 Hz: the prior one-second gap allowed fast compiler
        # allocations to overshoot the reactive threshold substantially. This
        # remains a sampled guard, not an OS-enforced memory cap.
        sleep "$rss_poll_interval_seconds"
    done

    if [ -n "$compiler_pid" ]; then
        wait "$compiler_pid" 2>/dev/null || compiler_exit=$?
        compiler_pid=""
        compiler_pgid=""
    fi
    final_log_bytes="$(wc -c <"$log_file" | tr -d '[:space:]')"
    case "$final_log_bytes" in
        ''|*[!0-9]*)
            output_guard=1
            final_log_bytes=unavailable
            if ! latch_validation_disabled "run_bounded_lowering final_log_measurement_failed"; then
                echo "run_bounded_lowering: unable to latch after final log-measurement failure" >&2
            fi
            ;;
        *)
            if [ "$final_log_bytes" -gt "$effective_log_limit_bytes" ]; then
                output_guard=1
                if ! latch_validation_disabled "run_bounded_lowering post_exit_output_guard log_bytes=$final_log_bytes limit_bytes=$effective_log_limit_bytes"; then
                    echo "run_bounded_lowering: unable to latch after post-exit output-limit breach" >&2
                fi
            fi
            ;;
    esac
    finished_at="$(date +%s)"
    if ! {
        printf 'run_status=completed\nfinished_epoch=%s\ncompiler_exit_status=%s\nmax_observed_rss_kb=%s\nrss_samples=%s\n' "$finished_at" "$compiler_exit" "$peak_rss_kb" "$rss_sample_count"
        printf 'rss_guard=%s\ntimeout_guard=%s\noutput_guard=%s\nfinal_log_bytes=%s\n' "$rss_guard" "$timeout_guard" "$output_guard" "$final_log_bytes"
    } >>"$metadata_file"; then
        echo "run_bounded_lowering: unable to finalize run metadata; preserving partial evidence" >&2
        exit 125
    fi
    metadata_finalized=1
    # The PID is no longer owned after wait; clear it before any diagnostic or
    # exit path so the EXIT trap cannot mistake a reused PID for our compiler.
    compiler_pid=""
    compiler_pgid=""
    echo "$source_file exit=$compiler_exit max_observed_rss_kb=$peak_rss_kb rss_samples=$rss_sample_count rss_guard=$rss_guard timeout_guard=$timeout_guard output_guard=$output_guard log=$log_file metadata=$metadata_file"
    if [ "$compiler_exit" -ne 0 ] || [ "$rss_guard" -ne 0 ] || [ "$timeout_guard" -ne 0 ] || [ "$output_guard" -ne 0 ]; then
        tail -80 "$log_file"
        exit 1
    fi
    if ! rm -f "$source_snapshot"; then
        echo "run_bounded_lowering: unable to remove the completed source snapshot; preserving run evidence" >&2
        exit 125
    fi
    source_snapshot=""
    log_file=""
    metadata_file=""
    metadata_finalized=0
    compiler_pid=""
    compiler_pgid=""
done
