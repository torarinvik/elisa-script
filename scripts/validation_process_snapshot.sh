#!/bin/sh

# Pure parsers for bounded `ps` snapshots used by the validation wrappers.
# Input includes a final __ELISASCRIPT_PS_STATUS__ row emitted by the caller.
# Keeping parsing separate lets compiler-free fixtures exercise the exact RSS
# and descendant-selection logic without starting a compiler or any process.

validation_owned_process_group_id() {
    validation_group_root="$1"
    validation_group_candidate="$2"
    validation_group_wrapper="$3"
    case "$validation_group_root:$validation_group_candidate:$validation_group_wrapper" in
        ''|:*|*::*) return 1 ;;
        *[!0-9:]*) return 1 ;;
    esac
    [ "$validation_group_root" != "0" ] || return 1
    [ "$validation_group_candidate" != "0" ] || return 1
    [ "$validation_group_candidate" = "$validation_group_root" ] || return 1
    [ "$validation_group_candidate" != "$validation_group_wrapper" ] || return 1
    printf '%s\n' "$validation_group_candidate"
}

validation_process_group_has_live_members_from_snapshot() {
    awk -v group="$1" -v row_limit="$2" '
        NR > row_limit + 1 { overflow = 1; exit }
        $1 == "__ELISASCRIPT_PS_STATUS__" {
            if (status_seen || NF != 2 || $2 !~ /^[0-9]+$/) malformed = 1
            status_seen = 1
            if ($2 != 0) ps_failed = 1
            next
        }
        ++process_rows > row_limit { overflow = 1; exit }
        $1 !~ /^[0-9]+$/ || NF != 2 || $2 == "" { malformed = 1; exit }
        {
            if ($1 == group && $2 !~ /^Z/) found = 1
        }
        END {
            # Success means either a live member was found or the snapshot was
            # uncertain. Only a valid complete snapshot can authorize release.
            if (overflow || malformed || ps_failed || !status_seen || process_rows > row_limit || NR > row_limit + 1 || found) exit 0
            exit 1
        }
    '
}

validation_process_state_from_snapshot() {
    awk -v target="$1" -v row_limit="$2" '
        BEGIN { if (target !~ /^[0-9]+$/ || target == "0") malformed = 1 }
        NR > row_limit + 1 { overflow = 1; exit }
        $1 == "__ELISASCRIPT_PS_STATUS__" {
            if (status_seen || NF != 2 || $2 !~ /^[0-9]+$/) malformed = 1
            status_seen = 1
            if ($2 != 0) ps_failed = 1
            next
        }
        ++process_rows > row_limit { overflow = 1; exit }
        $1 !~ /^[0-9]+$/ || NF != 2 || $2 == "" { malformed = 1; exit }
        {
            if ($1 == target) {
                target_rows++
                target_state = $2
            }
        }
        END {
            if (overflow || malformed || ps_failed || !status_seen || process_rows > row_limit || NR > row_limit + 1 || target_rows > 1) {
                print "unknown"
                exit 0
            }
            if (!target_rows) {
                print "absent"
                exit 0
            }
            if (target_state ~ /^Z/) print "zombie"
            else print "live"
        }
    '
}

validation_process_tree_pids_from_snapshot() {
    awk -v root="$1" -v row_limit="$2" '
        NR > row_limit + 1 { overflow = 1; exit }
        $1 == "__ELISASCRIPT_PS_STATUS__" {
            if (status_seen || NF != 2 || $2 !~ /^[0-9]+$/) malformed = 1
            status_seen = 1
            if ($2 != 0) ps_failed = 1
            next
        }
        ++process_rows > row_limit { overflow = 1; exit }
        $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ || NF != 2 { malformed = 1; exit }
        {
            present[$1] = 1
            children[$2] = children[$2] " " $1
        }
        END {
            if (overflow || malformed || ps_failed || !status_seen || process_rows > row_limit || NR > row_limit + 1) exit 2
            if (!(root in present)) exit 0
            head = 1
            tail = 1
            queue[tail] = root
            seen[root] = 1
            print root
            while (head <= tail) {
                parent_pid = queue[head++]
                child_count = split(children[parent_pid], child_ids, " ")
                for (child_index = 1; child_index <= child_count; child_index++) {
                    child_pid = child_ids[child_index]
                    if (child_pid ~ /^[0-9]+$/ && !seen[child_pid]) {
                        seen[child_pid] = 1
                        queue[++tail] = child_pid
                        print child_pid
                    }
                }
            }
        }
    '
}

validation_process_group_rss_from_snapshot() {
    awk -v group="$1" -v root="$2" -v row_limit="$3" '
        NR > row_limit + 1 { overflow = 1; exit }
        $1 == "__ELISASCRIPT_PS_STATUS__" {
            if (status_seen || NF != 2 || $2 !~ /^[0-9]+$/) malformed = 1
            status_seen = 1
            if ($2 != 0) ps_failed = 1
            next
        }
        ++process_rows > row_limit { overflow = 1; exit }
        $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ || $3 !~ /^[0-9]+$/ || $4 !~ /^[0-9]+$/ || NF != 4 { malformed = 1; exit }
        {
            pid = $1
            process_group[$1] = $3
            rss[$1] = $4
            present[$1] = 1
            children[$2] = children[$2] " " $1
            if (pid == root || $3 == group) scope_seen = 1
        }
        END {
            if (overflow || malformed || ps_failed || !status_seen || process_rows > row_limit || NR > row_limit + 1) exit 2
            if (!scope_seen) exit 1
            if (root in present) {
                head = 1
                tail = 1
                queue[tail] = root
                tree_pid[root] = 1
                while (head <= tail) {
                    parent_pid = queue[head++]
                    child_count = split(children[parent_pid], child_ids, " ")
                    for (child_index = 1; child_index <= child_count; child_index++) {
                        child_pid = child_ids[child_index]
                        if (child_pid ~ /^[0-9]+$/ && !tree_pid[child_pid]) {
                            tree_pid[child_pid] = 1
                            queue[++tail] = child_pid
                        }
                    }
                }
            }
            for (pid in present) {
                if (process_group[pid] == group || tree_pid[pid]) total += rss[pid]
            }
            print total + 0
        }
    '
}
