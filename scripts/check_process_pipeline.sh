#!/usr/bin/env bash

# Compiler-free audit for ordered shell-free process pipelines.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/process_model.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'process pipeline audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'PROCESS_PIPELINE_MAX_STAGES' \
    'PROCESS_PIPELINE_MAX_BUFFER_BYTES' \
    'const enum ProcessPipelineFailureMode of u8:' \
    'const enum ProcessPipelineStatusPolicy of u8:' \
    'const enum ProcessPipelineState of u8:' \
    'const enum ProcessPipelineStageState of u8:' \
    'const enum ProcessPipelineEvent of u8:' \
    'struct ProcessPipeline:' \
    'error ProcessPipelineError:' \
    'def validate_process_pipeline(' \
    'def advance_process_pipeline('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'process_pipeline_state_valid' \
    'process_pipeline_event_valid' \
    'ProcessPipelineEvent.StageFailure, ProcessPipelineEvent.StageCancel, ProcessPipelineEvent.Cancel' \
    'ProcessPipelineStageState.Pending' \
    'pipeline.stage_states.count != pipeline.stages.count' \
    'process_pipeline_failure_mode_valid' \
    '            LastStage' \
    '            Pipefail' \
    'InvalidStageCommand' \
    'InvalidStageIndex' \
    'InvalidStageState' \
    'ProcessPipelineFailureMode.Aggregate' \
    'ProcessPipelineEvent.StageStart' \
    'ProcessPipelineEvent.StageFailure' \
    'ProcessPipelineEvent.StageCancel' \
    'ProcessPipelineState.Cancelling' \
    'pipeline.completed_stages != derived_completed' \
    'pipeline.failed_stages != derived_failed' \
    'pipeline.cancelled_stages != derived_cancelled' \
    'pipeline.failure_mode == ProcessPipelineFailureMode.FailFast and pipeline.failed_stages != 0' \
    'pipeline.cancelled_stages != 0' \
    'pipeline.state == ProcessPipelineState.Planned and event != ProcessPipelineEvent.Start and event != ProcessPipelineEvent.Cancel' \
    'pipeline.completed_stages != pipeline.stages.count' \
    'pipeline.cancellation_requested' \
    'ProcessPipelineEvent.CancelAck'; do
    rg -Fq "$boundary" "$model"
done

for fixture_pattern in \
    'typed_process_pipeline_contract_models_concurrent_cancellation' \
    'ProcessPipelineFailureMode.Aggregate' \
    'ProcessPipelineEvent.StageStart' \
    'ProcessPipelineEvent.StageExit' \
    'ProcessPipelineEvent.StageFailure' \
    'ProcessPipelineError.InvalidStageState' \
    'ProcessPipelineEvent.CancelAck' \
    'ProcessPipelineError.InvalidStageCommand'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`ProcessPipeline`' "$docs"
rg -Fq '`ProcessPipeline`' "$ledger"
rg -Fq 'P10 pipeline follow-up' "$plan"

printf 'process pipeline audit: typed stages, bounded buffers, out-of-order lifecycle, failure policy, and cancellation edges are present\n'
