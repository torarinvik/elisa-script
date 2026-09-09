#!/usr/bin/env bash

# Compiler-free audit for paired continuation id/value pool slices.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
interpreter_tests="$repo_root/test/ir/elisascript_interpreter_test.elisa"
ir_tests="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
policy="$repo_root/docs/continuation-policy.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$interpreter" "$interpreter_tests" "$ir_tests" "$docs" "$policy" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'continuation pool audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for required_text in \
    'value_snapshot_start: usize' \
    'value_snapshot_count: usize' \
    'frame.snapshot_count != frame.value_snapshot_count' \
    'frame.snapshot_start > machine.continuation_ids.count' \
    'frame.snapshot_count > machine.continuation_ids.count - frame.snapshot_start' \
    'frame.value_snapshot_start > machine.continuation_values.count' \
    'frame.value_snapshot_count > machine.continuation_values.count - frame.value_snapshot_start' \
    'frame.handler_snapshot_start > machine.continuation_handlers.count' \
    'frame.handler_snapshot_count > machine.continuation_handlers.count - frame.handler_snapshot_start' \
    'machine.continuation_values[frame.value_snapshot_start + offset]' \
    'machine.continuation_values[replay_frame.value_snapshot_start + offset]' \
    'machine.continuation_values.truncate(value_snapshot_start)' \
    'continuation_pool_append_fits(machine.continuation_values.count, values.count' \
    'if continuation.replay_start > machine.continuation_frames.count' \
    'if continuation.replay_count > machine.continuation_frames.count - continuation.replay_start' \
    'continuation_frame_storage_valid(machine, frame)'; do
    rg -Fq "$required_text" "$interpreter" || {
        printf 'continuation pool audit: interpreter omits %s\n' "$required_text" >&2
        exit 1
    }
done

if rg -q 'continuation_values\[frame\.snapshot_start' "$interpreter"; then
    printf 'continuation pool audit: active snapshot still uses the id-pool start for values\n' >&2
    exit 1
fi

for fixture_pattern in \
    'interpreter_executes_repeated_resumes_for_multi_shot_handler' \
    'interpreter_replays_multi_shot_helper_and_caller_frames' \
    'interpreter_rejects_multi_shot_mutable_snapshot_views'; do
    rg -q "$fixture_pattern" "$interpreter_tests" || {
        printf 'continuation pool audit: missing runtime fixture %s\n' "$fixture_pattern" >&2
        exit 1
    }
done

rg -q 'verifier_rejects_malformed_continuation_capture_metadata' "$ir_tests"
rg -q 'Snapshot ids, values, handler names' "$docs"
rg -q 'independent starts and counts for its SSA-id' "$policy"
rg -q 'Continuation-pool slice increment' "$plan"
rg -q 'ES-EFF-001' "$ledger"

printf 'continuation pool audit: id/value starts, paired counts, replay indexing, and reclamation are present\n'
