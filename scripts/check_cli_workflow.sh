#!/usr/bin/env bash

# Compiler-free audit for mode-specific CLI workflow planning.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/cli_workflow_model.elisa"
cli_model="$repo_root/src/runtime/cli_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$cli_model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'cli workflow audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsCliWorkflow:' \
    'CLI_WORKFLOW_MAX_STEPS' \
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
    'workflow.state == CliWorkflowState.Complete' \
    'workflow.state == CliWorkflowState.Failed or workflow.state == CliWorkflowState.Cancelled' \
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
rg -Fq 'using EsCliWorkflow' "$fixture"
for fixture_pattern in \
    'typed_cli_workflow_contract_maps_modes_to_ordered_steps' \
    'CliWorkflowEvent.StepComplete' \
    'CliWorkflowStep.Verify' \
    'CliWorkflowStep.Format' \
    'CliWorkflowEvent.CancelAck'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsCliWorkflow separates planning from host execution' "$docs"
rg -Fq 'ES-SCRIPT-008 | EsCliWorkflow' "$ledger"
rg -Fq 'explicit EsCliWorkflow contract' "$plan"

printf 'cli workflow audit: mode-specific step plans, ordering validation, completion, failure, and cancellation are present\n'
