#!/usr/bin/env bash

# Compiler-free audit for ordered shell-free process pipelines.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/process_model.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'process pipeline audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'PROCESS_PIPELINE_MAX_STAGES' \
    'PROCESS_PIPELINE_MAX_BUFFER_BYTES' \
    'const enum ProcessPipelineFailureMode of u8:' \
    'const enum ProcessPipelineStatusPolicy of u8:' \
    'const enum ProcessPipelineState of u8:' \
    'const enum ProcessPipelineStageState of u8:' \
    'const enum ProcessPipelineStream of u8:' \
    'const enum ProcessPipelineEvent of u8:' \
    'struct ProcessPipelineStageResult:' \
    'struct ProcessPipeline:' \
    'error ProcessPipelineError:' \
    'def validate_process_pipeline(' \
    'def advance_process_pipeline('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'process_pipeline_state_valid' \
    'process_pipeline_event_valid' \
    'process_pipeline_stream_valid' \
    'process_pipeline_stage_result_valid' \
    'not was_pending and result.result.kind == ProcessResultKind.SpawnFailure' \
    'ProcessPipelineEvent.StageOutput' \
    'pipeline.stage_results.count != pipeline.stages.count' \
    'pipeline.stream_bytes' \
    'ProcessPipelineError.InvalidReceipt' \
    'ProcessPipelineError.PipelineNotDrained' \
    'ProcessPipelineError.OutputLimitExceeded' \
    'ProcessPipelineError.ChannelAccountingInvalid' \
    'ProcessPipelineEvent.StageOutput, ProcessPipelineEvent.StageExit, ProcessPipelineEvent.StageFailure, ProcessPipelineEvent.StageCancel' \
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
    'ProcessPipelineStream.Stdout' \
    'ProcessPipelineStream.Stdin' \
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
    'ProcessPipelineEvent.StageOutput' \
    'ProcessPipelineEvent.StageExit' \
    'ProcessPipelineEvent.StageFailure' \
    'ProcessPipelineEvent.StageCancel' \
    'ProcessPipelineStream.Stdout' \
    'ProcessPipelineStream.Stdin' \
    'ProcessPipelineError.InvalidStageState' \
    'ProcessPipelineError.InvalidReceipt' \
    'ProcessPipelineError.PipelineNotDrained' \
    'ProcessPipelineError.OutputLimitExceeded' \
    'launch_failure_receipt' \
    'ProcessPipelineEvent.CancelAck' \
    'ProcessPipelineError.InvalidStageCommand'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`ProcessPipeline`' "$docs"
rg -Fq '`ProcessPipeline`' "$ledger"

printf 'process pipeline audit: typed stages, drained receipts, bounded stream bytes, failure policy, and cancellation edges are present\n'
