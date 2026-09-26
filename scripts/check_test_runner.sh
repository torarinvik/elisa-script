#!/usr/bin/env bash

# Compiler-free audit for typed test discovery, execution, retry, and reports.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/test_runner_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'test runner audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsTestRunner:' \
    'const module Limits:' \
    'const enum TestRetryPolicy of u8' \
    'const enum TestRunnerState of u8' \
    'const enum TestCaseState of u8' \
    'const enum TestOutcome of u8' \
    'const enum TestRunnerEvent of u8' \
    'struct TestSpec:' \
    'struct TestResult:' \
    'struct TestCase:' \
    'struct TestRunner:' \
    'error TestRunnerError:' \
    'def validate_test_runner(' \
    'def advance_test_runner('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'Limits::TESTS' \
    'Limits::NAME_BYTES' \
    'Limits::SELECTION_REASON_BYTES' \
    'Limits::MESSAGE_BYTES' \
    'Limits::ATTEMPTS' \
    'Limits::PARALLEL' \
    'Limits::OUTPUT_BYTES' \
    'test_runner_refresh_accounting' \
    'test_runner_accounting_matches' \
    'test_runner_all_terminal' \
    'test_outcome_retryable' \
    'test_result_unpublished_valid' \
    'TestRunnerError.DuplicateTestId' \
    'TestRunnerError.DuplicateTestName' \
    'TestRunnerError.StaleAttempt' \
    'TestRunnerError.AttemptLimitExceeded' \
    'TestRunnerError.ParallelLimitExceeded' \
    'TestRunnerError.CompletionNotReady' \
    'TestRunnerError.ReportNotReady' \
    'TestRunnerError.CancelNotReady' \
    'OutputDocumentEvent.Begin' \
    'OutputDocumentEvent.Append' \
    'OutputDocumentEvent.Seal' \
    'attempt_token' \
    'ProcessResultKind.SpawnFailure' \
    'runner stopped after test failure' \
    'process.error_text' \
    'effective_message' \
    'TestOutcome.Flaky and attempts < 2' \
    'OutputStatus.Flaky if case.state == TestCaseState.Flaky' \
    'failure_latched' \
    'cancellation_requested'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/test_runner_model.elisa"' "$ir"
rg -Fq 'using EsTestRunner' "$fixture"
for fixture_pattern in \
    'typed_test_runner_contract_discovers_retries_and_seals_reports' \
    'TestRunnerEvent.Discover' \
    'TestRunnerEvent.SelectionDone' \
    'TestRunnerEvent.Launch' \
    'TestRunnerEvent.Complete' \
    'TestRunnerEvent.Retry' \
    'TestRunnerEvent.Fail' \
    'TestRunnerEvent.BeginReport' \
    'TestRunnerEvent.SealReport' \
    'TestRunnerError.StaleAttempt' \
    'TestCaseState.Retryable' \
    'TestCaseState.Flaky' \
    'typed_test_runner_contract_latches_exhausted_failures_and_unexpected_cancellation' \
    'TestRunnerState.Failed' \
    'TestOutcome.Error' \
    'OutputDocumentState.Sealed' \
    'forged_hidden_failure' \
    'forged_reporting_failure'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsTestRunner` builds the test/CI layer' "$docs"
rg -Fq 'ES-TEST-001' "$ledger"

printf 'test runner audit: bounded discovery, selection, retries, cancellation, and sealed reports are present\n'
