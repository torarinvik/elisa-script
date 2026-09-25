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

owned_group="$(validation_owned_process_group_id 301 301 100)"
assert_equal 301 "$owned_group" 'session-leader PGID is safe to signal'
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

printf '%s\n' 'process snapshot fixture: group-signal identity/liveness, descendant traversal, RSS union, reparenting, malformed/failed/truncated snapshots covered'
