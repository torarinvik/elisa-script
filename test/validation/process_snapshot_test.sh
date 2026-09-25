#!/bin/sh

# Compiler-free fixture tests for the exact process-table parsers used by the
# disabled validation wrappers. This test creates no child processes.
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")/../../scripts" && pwd)"
. "$script_dir/validation_process_snapshot.sh"

fail() {
    printf 'process snapshot fixture: %s\n' "$1" >&2
    exit 1
}

assert_equal() {
    expected="$1"
    actual="$2"
    description="$3"
    if [ "$actual" != "$expected" ]; then
        printf 'process snapshot fixture: %s (expected <%s>, got <%s>)\n' "$description" "$expected" "$actual" >&2
        exit 1
    fi
}

assert_parser_failure() {
    failure_input="$1"
    parser_kind="$2"
    description="$3"
    if [ "$parser_kind" = tree ]; then
        if parser_output="$(printf '%s\n' "$failure_input" | validation_process_tree_pids_from_snapshot 10 2)"; then
            fail "$description unexpectedly succeeded: $parser_output"
        else
            parser_status=$?
        fi
    elif [ "$parser_kind" = identities ]; then
        if parser_output="$(printf '%s\n' "$failure_input" | validation_process_tree_identities_from_snapshot 100 2)"; then
            fail "$description unexpectedly succeeded: $parser_output"
        else
            parser_status=$?
        fi
    else
        if parser_output="$(printf '%s\n' "$failure_input" | validation_process_group_rss_from_snapshot 10 10 2)"; then
            fail "$description unexpectedly succeeded: $parser_output"
        else
            parser_status=$?
        fi
    fi
    [ "$parser_status" -eq 2 ] || fail "$description returned $parser_status instead of fail-closed status 2"
}

assert_group_liveness_status() {
    liveness_input="$1"
    expected_status="$2"
    description="$3"
    if printf '%s\n' "$liveness_input" | validation_process_group_has_live_members_from_snapshot 10 2; then
        actual_status=0
    else
        actual_status=$?
    fi
    assert_equal "$expected_status" "$actual_status" "$description"
}

assert_process_state() {
    state_input="$1"
    target_pid="$2"
    expected_state="$3"
    description="$4"
    actual_state="$(printf '%s\n' "$state_input" | validation_process_state_from_snapshot "$target_pid" 4)"
    assert_equal "$expected_state" "$actual_state" "$description"
}

owned_group="$(validation_owned_process_group_id 301 301 100)"
assert_equal 301 "$owned_group" 'session-leader PGID is safe to signal'
validation_process_start_token_matches 'Mon-Sep-25-10:00:00-2026' 'Mon-Sep-25-10:00:00-2026' || fail 'matching process start token was rejected'
if validation_process_start_token_matches 'Mon-Sep-25-10:00:00-2026' 'Mon-Sep-25-10:00:01-2026'; then
    fail 'different process start token was accepted'
fi
if validation_process_start_token_matches 'Mon-Sep-25-10:00:00-2026' ''; then
    fail 'missing process start token was accepted'
fi
for rejected_group_case in '301 100 100' '301 302 100' '0 0 100' '301 bad 100'; do
    set -- $rejected_group_case
    if owned_group="$(validation_owned_process_group_id "$1" "$2" "$3")"; then
        fail "unsafe process group accepted: $rejected_group_case -> $owned_group"
    fi
done

assert_group_liveness_status '10 S
__ELISASCRIPT_PS_STATUS__ 0' 0 'live member keeps group leader unreaped'
assert_group_liveness_status '10 Z
__ELISASCRIPT_PS_STATUS__ 0' 1 'zombie-only group permits leader release'
assert_group_liveness_status '11 R
__ELISASCRIPT_PS_STATUS__ 0' 1 'unrelated group does not retain leader'
assert_group_liveness_status '10 S
__ELISASCRIPT_PS_STATUS__ 1' 0 'failed liveness snapshot conservatively retains leader'
assert_group_liveness_status '10 S' 0 'missing liveness sentinel conservatively retains leader'
assert_group_liveness_status '10
__ELISASCRIPT_PS_STATUS__ 0' 0 'malformed liveness row conservatively retains leader'
assert_group_liveness_status '10 S unexpected
__ELISASCRIPT_PS_STATUS__ 0' 0 'extra liveness fields conservatively retain leader'
assert_group_liveness_status '10 S
11 R
12 R
__ELISASCRIPT_PS_STATUS__ 0' 0 'oversized liveness snapshot conservatively retains leader'

state_snapshot='10 S
11 Z+
__ELISASCRIPT_PS_STATUS__ 0'
assert_process_state "$state_snapshot" 10 live 'live compiler process state'
assert_process_state "$state_snapshot" 11 zombie 'zombie compiler process state'
assert_process_state "$state_snapshot" 12 absent 'absent compiler process state'
assert_process_state '10 S
__ELISASCRIPT_PS_STATUS__ 1' 10 unknown 'failed process-state snapshot'
assert_process_state '10 S' 10 unknown 'missing process-state sentinel'
assert_process_state '10 S
11 R
12 R
13 S
14 R
__ELISASCRIPT_PS_STATUS__ 0' 10 unknown 'oversized process-state snapshot'
assert_process_state '10 S
10 R
__ELISASCRIPT_PS_STATUS__ 0' 10 unknown 'duplicate process-state row'

identity_snapshot='100 1 100 Mon Sep 25 10:00:00 2026
101 100 101 Mon Sep 25 10:01:00 2026
__ELISASCRIPT_PS_STATUS__ 0'
tree_identities="$(printf '%s\n' "$identity_snapshot" | validation_process_tree_identities_from_snapshot 100 4)"
assert_equal '100@100@Mon-Sep-25-10:00:00-2026
101@101@Mon-Sep-25-10:01:00-2026' "$tree_identities" 'tree identities preserve PGID and process start time'
assert_parser_failure '100 1 100 Mon Sep 25 10:00:00 2026
101 100 101 bad Sep 25 10:01:00 2026
__ELISASCRIPT_PS_STATUS__ 0' identities 'malformed process identity row'
assert_parser_failure '100 1 100 Mon Sep 25 10:00:00 2026
101 100 101 Mon Sep 25 10:01:00 2026
102 100 102 Mon Sep 25 10:02:00 2026
__ELISASCRIPT_PS_STATUS__ 0' identities 'process identity row-limit overflow'
assert_parser_failure '100 1 100 Mon Sep 25 10:00:00 2026' identities 'missing process-identity sentinel'
assert_parser_failure '100 1 100 Mon Sep 25 10:00:00 2026
__ELISASCRIPT_PS_STATUS__ 1' identities 'failed process-identity snapshot'

tree_snapshot='10 1
11 10
12 11
__ELISASCRIPT_PS_STATUS__ 0'
tree_result="$(printf '%s\n' "$tree_snapshot" | validation_process_tree_pids_from_snapshot 10 4)"
assert_equal '10
11
12' "$tree_result" 'breadth-first descendant snapshot'

missing_root="$(printf '%s\n' '__ELISASCRIPT_PS_STATUS__ 0' | validation_process_tree_pids_from_snapshot 10 4)"
assert_equal '' "$missing_root" 'exited process root is an empty snapshot'

assert_parser_failure '10 1
11 x
__ELISASCRIPT_PS_STATUS__ 0' tree 'malformed descendant row'
assert_parser_failure '10 1 extra
__ELISASCRIPT_PS_STATUS__ 0' tree 'extra descendant fields'
assert_parser_failure '10 1
11 10
12 10
__ELISASCRIPT_PS_STATUS__ 0' tree 'descendant row-limit overflow'
assert_parser_failure '10 1
__ELISASCRIPT_PS_STATUS__ 1' tree 'failed descendant process-table command'
assert_parser_failure '10 1' tree 'missing descendant status sentinel'

rss_snapshot='10 1 10 30
11 10 10 40
12 11 12 50
13 1 10 20
14 1 14 900
__ELISASCRIPT_PS_STATUS__ 0'
rss_result="$(printf '%s\n' "$rss_snapshot" | validation_process_group_rss_from_snapshot 10 10 8)"
assert_equal 140 "$rss_result" 'union of process group and root descendants without double counting'

orphaned_group_snapshot='13 1 10 20
__ELISASCRIPT_PS_STATUS__ 0'
orphaned_group_rss="$(printf '%s\n' "$orphaned_group_snapshot" | validation_process_group_rss_from_snapshot 10 10 2)"
assert_equal 20 "$orphaned_group_rss" 'reparented process retained in the owned process group'

assert_parser_failure '10 1 10 bad
__ELISASCRIPT_PS_STATUS__ 0' rss 'malformed RSS row'
assert_parser_failure '10 1 10 30 extra
__ELISASCRIPT_PS_STATUS__ 0' rss 'extra RSS fields'
assert_parser_failure '10 1 10 30
11 10 10 40
12 11 12 50
__ELISASCRIPT_PS_STATUS__ 0' rss 'RSS row-limit overflow'
assert_parser_failure '10 1 10 30
__ELISASCRIPT_PS_STATUS__ 1' rss 'failed RSS process-table command'
assert_parser_failure '10 1 10 30' rss 'missing RSS status sentinel'

printf '%s\n' 'process snapshot fixture: group-signal identity/liveness, process start identities, process states, descendant traversal, RSS union, reparenting, malformed/failed/truncated snapshots covered'
