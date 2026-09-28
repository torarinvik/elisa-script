#!/usr/bin/env bash

# Compiler-free audit for in-process @test discovery and execution.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/script_test_model.elisa"
runner="$repo_root/src/ir/runner.elisa"
execution="$repo_root/src/ir/execution.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
runner_fixture="$repo_root/test/ir/elisascript_runner_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$runner" "$execution" "$ir" "$fixture" "$runner_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'script test audit: missing %s\n' "$required_file" >&2; exit 1; }
done

# The execution facade is a separate include root used by the native driver.
# Keep its test/report dependencies explicit so a source-only include reduction
# cannot leave runner symbols available in IR fixtures but missing at the
# actual launcher boundary.
rg -Fq 'include "../runtime/output_model.elisa"' "$execution"
rg -Fq 'include "../runtime/script_test_model.elisa"' "$execution"

for declaration in \
    'module EsScriptTest:' \
    'const module Limits:' \
    'const enum ScriptTestCaseState of u8' \
    'const enum ScriptTestState of u8' \
    'const enum ScriptTestEvent of u8' \
    'struct ScriptTestSpec:' \
    'struct ScriptTestFailure:' \
    'struct ScriptTestSession:' \
    'name_order: mutable darray[usize]' \
    'error ScriptTestError:' \
    'def validate_script_test_spec(' \
    'def validate_script_test_session(' \
    'def advance_script_test(' \
    'def select_script_test_session('; do
    rg -Fq "$declaration" "$model"
done

for runner_declaration in \
    'using EsScriptTest' \
    'def discover_elisascript_file_tests_with_handlers(' \
    'def discover_elisascript_file_tests(' \
    'def discover_elisascript_source_tests_with_handlers(' \
    'def discover_elisascript_source_tests(' \
    'def discover_elisascript_source_bytes_tests_with_handlers(' \
    'def discover_elisascript_source_bytes_tests(' \
    'struct ElisascriptTestExecution:' \
    'struct ElisascriptTestRun:' \
    'def execute_elisascript_test(' \
    'def execute_elisascript_file_tests_with_handlers(' \
    'def execute_elisascript_file_tests(' \
    'def execute_elisascript_source_tests_with_handlers(' \
    'def execute_elisascript_source_tests(' \
    'def execute_elisascript_source_bytes_tests_with_handlers(' \
    'def execute_elisascript_source_bytes_tests(' \
    'def build_elisascript_test_report('; do
    rg -Fq "$runner_declaration" "$runner"
done

for boundary in \
    'TESTS: usize = 4096' \
    'NAME_BYTES' \
    'MESSAGE_BYTES' \
    'NO_ACTIVE' \
    'script_test_name_valid' \
    'script_test_message_valid' \
    'DuplicateName' \
    'InvalidCaseState' \
    'NoTests' \
    'CaseNotReady' \
    'CaseOrderInvalid' \
    'CancellationNotReady' \
    'FunctionNotFound' \
    'FunctionSignatureInvalid' \
    'NameIndexInvalid' \
    'name_order: mutable darray[usize]' \
    'SelectionLimitExceeded' \
    'SelectionInvalid' \
    'DuplicateSelection' \
    'SelectionNotFound' \
    'counted_cancelled' \
    'ScriptTestState.Cancelling' \
    'ScriptTestState.Cancelled' \
    'session.passed != session.next_case' \
    'session.cases[index].state <- ScriptTestCaseState.Cancelled' \
    'try validate_script_test_session(session)'; do
    rg -Fq "$boundary" "$model"
done
rg -Fq 'session.name_order.count != session.cases.count' "$model"
rg -Fq 'script_test_name_less(session.cases[previous_index].name, session.cases[case_index].name)' "$model"
rg -Fq 'session.name_order.push(new_case_index)' "$model"

for multi_case_boundary in \
    'elisascript_test_remaining_policy' \
    'elisascript_test_usage_add' \
    'cursor.state <- ElisascriptTestRunState.CaseBegin' \
    'ScriptTestEvent.CaseFail' \
    'ScriptTestEvent.CancelAck' \
    'result.runtime_error_known <- true' \
    'cursor.invocation_context' \
    'runtime_resource_policy_has_unaccounted_dimensions' \
    'successful completed-case' \
    'result.executions.push(ElisascriptTestExecution' \
    'elisascript_test_session_from_metadata' \
    'elisascript_run_test_module' \
    'elisascript_validate_test_run' \
    'elisascript_test_report_record' \
    'OutputDocumentEvent.Begin' \
    'OutputDocumentEvent.Seal' \
    'trailing planned cases' \
    'runner stopped after test failure' \
    'cancelled before launch'; do
    rg -Fq "$multi_case_boundary" "$runner"
done
rg -Uq 'def elisascript_record_pass_limits\([^\n]*\):\n[[:space:]]+raise ScriptTestError\.TestLimitExceeded if executions >= EsScriptTest::Limits::TESTS\n[[:space:]]+raise InterpretError\.OutputLimit if not elisascript_test_usage_add\(usage, addition, policy\)' "$runner"

rg -Fq 'include "../runtime/script_test_model.elisa"' "$ir"
rg -Fq 'using EsScriptTest' "$fixture"
for fixture_pattern in \
    'typed_script_test_contract_discovers_ordered_cases_and_reports_outcomes' \
    'ScriptTestEvent.Discover' \
    'ScriptTestEvent.Begin' \
    'ScriptTestEvent.CaseBegin' \
    'ScriptTestEvent.CasePass' \
    'ScriptTestEvent.CaseFail' \
    'ScriptTestEvent.Cancel' \
    'ScriptTestEvent.CancelAck' \
    'ScriptTestError.NoTests' \
    'ScriptTestError.DuplicateName' \
    'ScriptTestError.InvalidCaseState' \
    'ScriptTestCaseState.Cancelled' \
    'forged_running' \
    'forged_cancelled' \
    'NameIndexInvalid' \
    'typed_script_test_selection_is_exact_transactional_and_source_ordered' \
    'select_script_test_session' \
    'name_order: [1, 0]'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

for runner_fixture_pattern in \
    'runner_discovers_file_tests_without_requiring_main' \
    'discover_elisascript_file_tests(' \
    'runner_executes_one_void_test_with_fresh_case_storage' \
    'execute_elisascript_test(' \
    'ScriptTestError.FunctionSignatureInvalid' \
    'runner_executes_file_tests_in_source_order_with_suite_budget' \
    'execute_elisascript_file_tests(' \
    'runner_cancels_unstarted_file_tests_at_state_machine_boundary' \
    'cancel_requested: true' \
    'runner_maps_runtime_failure_to_typed_case_diagnostic' \
    'runtime_error == InterpretError.Assertion' \
    'runner stopped after test failure' \
    'cancelled before launch' \
    'runner_executes_source_buffer_tests_through_same_machine' \
    'runner_executes_only_exact_selected_tests_in_source_order' \
    'selected_names: selected' \
    'execute_elisascript_source_tests(' \
    'execute_elisascript_source_bytes_tests(' \
    'build_elisascript_test_report(' \
    'OutputStatus.Fail'; do
    rg -Fq "$runner_fixture_pattern" "$runner_fixture"
done

rg -Fq '`EsScriptTest` supplies' "$docs"
rg -Fq 'The runner' "$docs"
rg -Fq 'ES-TEST-002 | `EsScriptTest`' "$ledger"
rg -Fq 'ES-TEST-005 | runner discovery and single-case invocation' "$ledger"

printf 'script test audit: bounded discovery, exact selection, ordered execution, failure diagnostics, and cancellation are present\n'
