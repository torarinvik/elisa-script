#!/usr/bin/env bash

# Compiler-free audit for bounded task scopes and channels.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/task_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'task model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsTask:' \
    'TASK_MAX_CHILDREN' \
    'TASK_MAX_MESSAGES' \
    'TASK_MAX_MESSAGE_BYTES' \
    'const enum TaskFailureMode of u8:' \
    'const enum TaskScopeState of u8:' \
    'const enum TaskScopeEvent of u8:' \
    'struct TaskScope:' \
    'const enum TaskChannelState of u8:' \
    'const enum TaskChannelEvent of u8:' \
    'struct TaskChannel:' \
    'error TaskContractError:' \
    'def validate_task_scope(' \
    'def advance_task_scope(' \
    'def validate_task_channel(' \
    'def advance_task_channel(' \
    'def task_channel_send(' \
    'def task_channel_receive('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'task_scope_state_valid' \
    'task_scope_event_valid' \
    'task_channel_state_valid' \
    'ChildLimitExceeded' \
    'ChildAccountingInvalid' \
    'scope.state == TaskScopeState.Succeeded' \
    'scope.state == TaskScopeState.Closing' \
    'scope.state == TaskScopeState.Failed' \
    'scope.state == TaskScopeState.Cancelled' \
    'ChannelBufferExceeded' \
    'channel.buffered_messages == 0 and channel.buffered_bytes != 0' \
    'channel.buffered_messages != 0 and channel.buffered_bytes == 0' \
    'channel.state == TaskChannelState.Closing' \
    'channel.state == TaskChannelState.Closed' \
    'channel.state == TaskChannelState.Cancelled' \
    'ChannelEmpty' \
    'TaskScopeEvent.CancelAck' \
    'TaskChannelEvent.CancelAck'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/task_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_task_scope_and_channel_contract_is_bounded' \
    'TaskFailureMode.Aggregate' \
    'TaskContractError.ChannelBufferExceeded' \
    'TaskContractError.ChildAccountingInvalid' \
    'TaskChannelState.Closed'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsTask::TaskScope' "$docs"
rg -Fq 'EsTask::TaskScope' "$ledger"
rg -Fq 'P12 concurrency follow-up' "$plan"

printf 'task model audit: bounded scopes, child accounting, channel backpressure, and cancellation edges are present\n'
