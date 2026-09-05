#!/bin/sh

# Emergency stop for this repository's bounded validation worker only.
# It refuses unverifiable live lease owners and never searches for or kills
# unrelated compiler processes.

set -u
umask 077

validation_lease_dir="${TMPDIR:-/tmp}/elisascript-validation.lease"
validation_disabled_file="${TMPDIR:-/tmp}/elisascript-validation.disabled"

if ! printf '%s\n' "emergency-stop requested by stop_bounded_validation.sh" >"$validation_disabled_file"; then
    echo "stop_bounded_validation: unable to persist emergency-stop latch" >&2
    exit 2
fi

if [ ! -d "$validation_lease_dir" ]; then
    echo "stop_bounded_validation: latch set; no validation lease was present"
    exit 0
fi

if [ ! -f "$validation_lease_dir/owner.ready" ]; then
    echo "stop_bounded_validation: lease is still being initialized; refusing to kill an unverifiable owner" >&2
    exit 125
fi

owner_pid="$(sed -n '1p' "$validation_lease_dir/owner.pid" 2>/dev/null || true)"
owner_start="$(sed -n '1p' "$validation_lease_dir/owner.start" 2>/dev/null || true)"
case "$owner_pid" in
    ''|*[!0-9]*)
        echo "stop_bounded_validation: lease owner PID is malformed; refusing to kill it" >&2
        exit 125
        ;;
esac

if ! kill -0 "$owner_pid" 2>/dev/null; then
    echo "stop_bounded_validation: latch set; recorded owner is already stopped"
    exit 0
fi

owner_live_start="$(ps -o lstart= -p "$owner_pid" 2>/dev/null | sed 's/^[[:space:]]*//')"
owner_live_command="$(ps -o command= -p "$owner_pid" 2>/dev/null | sed 's/^[[:space:]]*//')"
case "$owner_live_command" in
    *run_bounded_lowering.sh*|*run_bounded_test.sh*) ;;
    *)
        echo "stop_bounded_validation: live lease owner is not a recognized wrapper; refusing to kill it" >&2
        exit 125
        ;;
esac
if [ -z "$owner_start" ] || [ "$owner_start" != "$owner_live_start" ]; then
    echo "stop_bounded_validation: lease owner identity was reused or is unverifiable; refusing to kill it" >&2
    exit 125
fi

process_tree_pids() {
    process_tree_root="$1"
    echo "$process_tree_root"
    for process_tree_child in $(pgrep -P "$process_tree_root" 2>/dev/null); do
        (process_tree_pids "$process_tree_child")
    done
}

process_tree_snapshot="$(process_tree_pids "$owner_pid")"
for process_tree_pid in $process_tree_snapshot; do
    kill -TERM "$process_tree_pid" 2>/dev/null || true
done
sleep 1
for process_tree_pid in $process_tree_snapshot; do
    kill -KILL "$process_tree_pid" 2>/dev/null || true
done

echo "stop_bounded_validation: emergency stop sent to the verified wrapper tree; latch remains set"
