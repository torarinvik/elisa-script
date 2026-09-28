#!/usr/bin/env bash

# Compiler-free audit for mode-specific CLI workflow planning.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/cli_workflow_model.elisa"
cli_model="$repo_root/src/runtime/cli_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
driver="$repo_root/src/driver/elisascript.elisa"
stdio="$repo_root/src/runtime/stdio_posix.elisa"
test_smoke="$repo_root/test/driver/elisascript_bounded_test_smoke.elisascript"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$cli_model" "$ir" "$fixture" "$driver" "$stdio" "$test_smoke" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'cli workflow audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsCliWorkflow:' \
    'const module Limits:' \
    'Limits::STEPS' \
    'const enum CliWorkflowStep of u8:' \
    'const enum CliWorkflowState of u8:' \
    'const enum CliWorkflowEvent of u8:' \
    'struct CliWorkflow:' \
    'error CliWorkflowError:' \
    'def validate_cli_workflow(' \
    'def plan_cli_workflow(' \
    'def advance_cli_workflow('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'workflow_mode_shape_valid' \
    'StepOrderInvalid' \
    'workflow.state == CliWorkflowState.Planned' \
    'workflow.state == CliWorkflowState.Running' \
    'workflow.state == CliWorkflowState.Cancelling' \
    'workflow.state == CliWorkflowState.Complete' \
    'workflow.state == CliWorkflowState.Failed or workflow.state == CliWorkflowState.Cancelled' \
    'and workflow.next_step >= workflow.steps.count' \
    'StepNotReady' \
    'InvocationInvalid' \
    'CliMode.Check' \
    'CliMode.Test' \
    'CliMode.Fmt' \
    'CliMode.Doc' \
    'CancelNotReady'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/cli_workflow_model.elisa"' "$ir"
rg -Fq 'request.mode == EsCli::CliMode.Test' "$driver"
rg -Fq 'execute_elisascript_file_tests' "$driver"
rg -Fq 'build_elisascript_test_report' "$driver"
rg -Fq 'write_output_document_fd' "$driver"
rg -Fq 'request.report_format <- invocation.report_format' "$driver"
rg -Fq 'requested_format == EsCli::CliReportFormat.Json' "$driver"
rg -Fq 'requested_format == EsCli::CliReportFormat.Junit' "$driver"
rg -Fq 'request.test_selection <- invocation.test_selection' "$driver"
rg -Fq 'selected_names: selected_names' "$driver"
rg -Fq 'json_options: OutputOptions = OutputOptions{format: OutputFormat.Json' "$repo_root/test/ir/elisascript_runner_test.elisa"
rg -Fq 'junit_options: OutputOptions = OutputOptions{format: OutputFormat.Junit' "$repo_root/test/ir/elisascript_runner_test.elisa"
rg -Fq 'elisascript_posix_isatty' "$driver"
rg -Fq 'def elisascript_posix_isatty(' "$stdio"
rg -Fq '@test' "$test_smoke"
rg -Fq 'using EsCliWorkflow' "$fixture"
for fixture_pattern in \
    'typed_cli_workflow_contract_maps_modes_to_ordered_steps' \
    'CliWorkflowEvent.StepComplete' \
    'CliWorkflowStep.Verify' \
    'CliWorkflowStep.ExecuteTests' \
    'CliWorkflowStep.Format' \
    'CliWorkflowEvent.CancelAck' \
    'forged_cancelling_cursor' \
    'assert validate_cli_workflow(cancellation)' \
    'failed_workflow' \
    'assert validate_cli_workflow(failed_workflow)'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsCliWorkflow separates planning from host execution' "$docs"
rg -Fq 'ES-SCRIPT-008 | EsCliWorkflow' "$ledger"

printf 'cli workflow audit: mode-specific step plans, ordering validation, completion, failure, and cancellation are present\n'
