#!/usr/bin/env bash

# Compiler-free audit for in-process @test discovery and execution.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/script_test_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'script test audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsScriptTest:' \
    'const module Limits:' \
    'const enum ScriptTestCaseState of u8' \
    'const enum ScriptTestState of u8' \
    'const enum ScriptTestEvent of u8' \
    'struct ScriptTestSpec:' \
    'struct ScriptTestFailure:' \
    'struct ScriptTestSession:' \
    'error ScriptTestError:' \
    'def validate_script_test_session(' \
    'def advance_script_test('; do
    rg -Fq "$declaration" "$model"
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
    'counted_cancelled' \
    'ScriptTestState.Cancelling' \
    'ScriptTestState.Cancelled' \
    'session.passed != session.next_case' \
    'session.cases[index].state <- ScriptTestCaseState.Cancelled' \
    'try validate_script_test_session(session)'; do
    rg -Fq "$boundary" "$model"
done

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
    'forged_cancelled'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsScriptTest` supplies' "$docs"
rg -Fq 'ES-TEST-002 | `EsScriptTest`' "$ledger"
rg -Fq 'In-process test state machine' "$plan"

printf 'script test audit: bounded discovery, ordered execution, failure diagnostics, and cancellation are present\n'
