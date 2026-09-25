#!/bin/sh

# Emergency stop for this repository's bounded validation worker only.
# It refuses unverifiable live lease owners and never searches for or kills
# unrelated compiler processes.

set -u
umask 077
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if ! . "$script_dir/validation_process_snapshot.sh"; then
    echo "stop_bounded_validation: unable to load process snapshot helpers; refusing to signal" >&2
    exit 125
fi
process_snapshot_row_limit=16384

validation_lease_dir="${TMPDIR:-/tmp}/elisascript-validation.lease"
validation_disabled_file="${TMPDIR:-/tmp}/elisascript-validation.disabled"

if [ -L "$validation_disabled_file" ] || { [ -e "$validation_disabled_file" ] && [ ! -d "$validation_disabled_file" ]; }; then
    echo "stop_bounded_validation: emergency-stop latch path is not a private directory" >&2
    exit 125
fi
if [ ! -d "$validation_disabled_file" ] && ! mkdir "$validation_disabled_file" 2>/dev/null; then
    echo "stop_bounded_validation: unable to create emergency-stop latch" >&2
    exit 2
fi
if [ ! -d "$validation_disabled_file" ]; then
    echo "stop_bounded_validation: emergency-stop latch path is not a directory" >&2
    exit 125
fi
if [ ! -e "$validation_disabled_file/reason" ]; then
    (set -C; printf '%s\n' "emergency-stop requested by stop_bounded_validation.sh" >"$validation_disabled_file/reason") 2>/dev/null || true
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

owner_live_start="$(LC_ALL=C ps -o lstart= -p "$owner_pid" 2>/dev/null | sed 's/^[[:space:]]*//')"
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

process_tree_identities() {
    process_tree_root="$1"
    process_snapshot="$( { LC_ALL=C ps -axo pid=,ppid=,pgid=,lstart= 2>/dev/null; process_snapshot_ps_status=$?; printf '__ELISASCRIPT_PS_STATUS__ %s\n' "$process_snapshot_ps_status"; } | head -n "$((process_snapshot_row_limit + 2))")" || return 1
    printf '%s\n' "$process_snapshot" | validation_process_tree_identities_from_snapshot "$process_tree_root" "$process_snapshot_row_limit"
}

process_snapshot_contains_pid() {
    process_snapshot_to_search="$1"
    process_snapshot_target_pid="$2"
    for process_snapshot_entry in $process_snapshot_to_search; do
        process_snapshot_entry_pid="${process_snapshot_entry%%@*}"
        [ "$process_snapshot_entry_pid" = "$process_snapshot_target_pid" ] && return 0
    done
    return 1
}

process_snapshot_group_for_pid() {
    process_snapshot_to_search="$1"
    process_snapshot_target_pid="$2"
    for process_snapshot_entry in $process_snapshot_to_search; do
        process_snapshot_entry_pid="${process_snapshot_entry%%@*}"
        if [ "$process_snapshot_entry_pid" = "$process_snapshot_target_pid" ]; then
            process_snapshot_entry_identity="${process_snapshot_entry#*@}"
            printf '%s\n' "${process_snapshot_entry_identity%%@*}"
            return 0
        fi
    done
    return 1
}

process_identity_matches() {
    process_identity_pid="$1"
    process_identity_expected_start="$2"
    process_identity_current_start="$(LC_ALL=C ps -o lstart= -p "$process_identity_pid" 2>/dev/null | awk '{ $1 = $1; gsub(/[[:space:]]+/, "-"); print }')"
    [ -n "$process_identity_current_start" ] && [ "$process_identity_current_start" = "$process_identity_expected_start" ]
}

owner_start_matches() {
    owner_live_start="$(LC_ALL=C ps -o lstart= -p "$owner_pid" 2>/dev/null | sed 's/^[[:space:]]*//')"
    [ -n "$owner_live_start" ] && [ "$owner_start" = "$owner_live_start" ] && kill -0 "$owner_pid" 2>/dev/null
}

if ! process_tree_snapshot="$(process_tree_identities "$owner_pid")"; then
    echo "stop_bounded_validation: process-tree snapshot is failed, malformed, or over limit; refusing to signal from incomplete data" >&2
    exit 125
fi
if ! process_snapshot_contains_pid "$process_tree_snapshot" "$owner_pid"; then
    echo "stop_bounded_validation: verified lease owner is absent from the process snapshot; refusing to signal" >&2
    exit 125
fi
owner_group_id="$(process_snapshot_group_for_pid "$process_tree_snapshot" "$owner_pid" 2>/dev/null || true)"
case "$owner_group_id" in
    ''|*[!0-9]*)
        echo "stop_bounded_validation: wrapper process group is unverifiable; refusing to signal" >&2
        exit 125
        ;;
esac
for process_tree_pid in $process_tree_snapshot; do
    process_pid="${process_tree_pid%%@*}"
    process_tree_identity="${process_tree_pid#*@}"
    process_group_id="${process_tree_identity%%@*}"
    process_start_token="${process_tree_identity#*@}"
    owned_group_id="$(validation_owned_process_group_id "$process_pid" "$process_group_id" "$owner_group_id" 2>/dev/null || true)"
    if [ -n "$owned_group_id" ] && process_identity_matches "$process_pid" "$process_start_token"; then
        kill -TERM -- "-$owned_group_id" 2>/dev/null || true
    fi
done
if ! owner_start_matches; then
    echo "stop_bounded_validation: verified owner stopped or changed identity after TERM; no stale PID escalation attempted"
    exit 0
fi
if ! term_tree_snapshot="$(process_tree_identities "$owner_pid")"; then
    echo "stop_bounded_validation: refreshed process-tree snapshot failed; refusing stale PID escalation" >&2
    exit 125
fi
if ! process_snapshot_contains_pid "$term_tree_snapshot" "$owner_pid"; then
    echo "stop_bounded_validation: verified lease owner is absent from the refreshed snapshot; refusing stale PID escalation" >&2
    exit 125
fi
for process_tree_pid in $term_tree_snapshot; do
    process_pid="${process_tree_pid%%@*}"
    process_tree_identity="${process_tree_pid#*@}"
    process_start_token="${process_tree_identity#*@}"
    if process_identity_matches "$process_pid" "$process_start_token"; then
        kill -TERM "$process_pid" 2>/dev/null || true
    fi
done
sleep 1
if ! owner_start_matches; then
    echo "stop_bounded_validation: verified owner stopped or changed identity after TERM; no stale PID escalation attempted"
    exit 0
fi
if ! kill_tree_snapshot="$(process_tree_identities "$owner_pid")"; then
    echo "stop_bounded_validation: refreshed process-tree snapshot failed; refusing stale PID escalation" >&2
    exit 125
fi
if ! process_snapshot_contains_pid "$kill_tree_snapshot" "$owner_pid"; then
    echo "stop_bounded_validation: verified lease owner is absent from the refreshed snapshot; refusing stale PID escalation" >&2
    exit 125
fi
owner_group_id="$(process_snapshot_group_for_pid "$kill_tree_snapshot" "$owner_pid" 2>/dev/null || true)"
case "$owner_group_id" in
    ''|*[!0-9]*)
        echo "stop_bounded_validation: refreshed wrapper process group is unverifiable; refusing to signal" >&2
        exit 125
        ;;
esac
for process_tree_pid in $kill_tree_snapshot; do
    process_pid="${process_tree_pid%%@*}"
    process_tree_identity="${process_tree_pid#*@}"
    process_group_id="${process_tree_identity%%@*}"
    process_start_token="${process_tree_identity#*@}"
    owned_group_id="$(validation_owned_process_group_id "$process_pid" "$process_group_id" "$owner_group_id" 2>/dev/null || true)"
    if [ -n "$owned_group_id" ] && process_identity_matches "$process_pid" "$process_start_token"; then
        kill -KILL -- "-$owned_group_id" 2>/dev/null || true
    fi
done
for process_tree_pid in $kill_tree_snapshot; do
    process_pid="${process_tree_pid%%@*}"
    process_tree_identity="${process_tree_pid#*@}"
    process_start_token="${process_tree_identity#*@}"
    if process_identity_matches "$process_pid" "$process_start_token"; then
        kill -KILL "$process_pid" 2>/dev/null || true
    fi
done

echo "stop_bounded_validation: emergency stop sent to the verified wrapper tree and private child groups; latch remains set"
