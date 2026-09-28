#!/usr/bin/env bash

# Compiler-free audit for the typed launcher argument boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/cli_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
contract="$repo_root/test/fixtures/script_parity/cli_launcher/CONTRACT.md"
docs="$repo_root/docs/ir.md"
driver="$repo_root/src/driver/elisascript.elisa"
runner="$repo_root/src/ir/runner.elisa"

for required_file in "$model" "$ir" "$fixture" "$contract" "$docs" "$driver" "$runner"; do
    [[ -f "$required_file" ]] || { printf 'cli model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsCli:' \
    'const module Limits:' \
    'Limits::ARGUMENTS' \
    'Limits::TEXT_BYTES' \
    'Limits::SOURCE_PATH_BYTES' \
    'Limits::TEST_SELECTIONS' \
    'Limits::TEST_NAME_BYTES' \
    'const enum CliMode of u8:' \
    'const enum CliColorMode of u8:' \
    'const enum CliReportFormat of u8:' \
    'report_format: mutable CliReportFormat' \
    'struct CliInvocation:' \
    'error CliContractError:' \
    'def validate_cli_invocation(' \
    'def parse_cli_arguments('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'cli_mode_valid' \
    'cli_color_valid' \
    'cli_report_format_valid' \
    'cli_report_format_from_argument' \
    'argument == "--format"' \
    'argument == "--select"' \
    'cli_mode_requires_source' \
    'DuplicateMode' \
    'DuplicateOption' \
    'UnexpectedArgument' \
    'TestArgumentsUnsupported' \
    'TestSelectionUnavailable' \
    'TestSelectionLimitExceeded' \
    'TestSelectionInvalid' \
    'DuplicateTestSelection' \
    'ReportFormatUnavailable' \
    'ColorNotApplicable' \
    'InvalidSourceExtension' \
    'MissingOptionValue' \
    'ArgumentLimitExceeded' \
    'SourcePathLimitExceeded' \
    'option_end_seen' \
    'arguments[index] == "--" and not invocation.option_end_seen'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'typed_cli_test_report_formats_are_mode_and_color_bounded' "$repo_root/test/runtime/cli_model_test.elisa"
rg -Fq 'typed_cli_test_selection_is_explicit_bounded_and_unique' "$repo_root/test/runtime/cli_model_test.elisa"
rg -Fq 'report_format: mutable CliReportFormat' "$runner"
rg -Fq 'result.report_format <- CliReportFormat.Human' "$runner"
rg -Fq 'test_selection: mutable darray[sview]' "$model"
rg -Fq 'test_selection: mutable darray[sview]' "$runner"

rg -Fq 'include "../runtime/cli_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_cli_contract_separates_launcher_options_from_script_arguments' \
    'typed_cli_launcher_budget_contract_matches_host_collector' \
    'CliMode.Check' \
    'CliColorMode.Never' \
    'CliContractError.DuplicateMode' \
    'CliContractError.UnknownOption' \
    'CliContractError.InvalidSourceExtension' \
    'CliContractError.UnexpectedArgument' \
    'CliContractError.DuplicateOption'; do
    rg -Fq "$fixture_pattern" "$fixture"
done
rg -Fq 'EsCli::Limits::TEST_SELECTIONS == EsScriptTest::Limits::TESTS' "$fixture"
rg -Fq 'EsCli::Limits::TEST_NAME_BYTES == EsScriptTest::Limits::NAME_BYTES' "$fixture"

rg -Fq '`EsCli::CliInvocation`' "$docs"
rg -Fq 'using EsCli' "$driver"
rg -Fq 'request.mode <- invocation.mode' "$driver"
rg -Fq 'request.report_format <- invocation.report_format' "$driver"
rg -Fq 'request.test_selection <- invocation.test_selection' "$driver"
rg -Fq 'selected_names: selected_names' "$driver"
rg -Fq 'requested_format == EsCli::CliReportFormat.Json' "$driver"
rg -Fq 'requested_format == EsCli::CliReportFormat.Junit' "$driver"
rg -Fq 'def build_test_setup_failure_report(' "$driver"
rg -Fq 'status: EsOutput::OutputStatus.Error, message: detail' "$driver"
rg -Fq 'def report_test_setup_failure_machine(' "$driver"
rg -Fq 'write_output_document_fd(report, 1, policy)' "$driver"
rg -Fq 'report_test_setup_failure_machine(requested_format, setup_detail)' "$driver"
rg -Fq 'request.strict_engine <- invocation.strict_engine' "$driver"
rg -Fq 'HostArgumentFailure.ArgumentBytes' "$driver"
rg -Fq 'argument_limit < EsIr::ES_RUNTIME_DEFAULT_MAX_CSTRING_BYTES - 1' "$driver"
rg -Fq 'script arguments exceed aggregate byte limit' "$driver"
rg -Fq 'request.strict_engine:' "$driver"
rg -Fq 'result.mode <- CliMode.Run' "$runner"
rg -Fq 'result.option_end_seen <- false' "$runner"
rg -Fq 'execute_elisascript_program_file_direct_only_diagnostic' "$driver"
rg -Fq 'request.mode == EsCli::CliMode.Check' "$driver"
rg -Fq 'check_elisascript_program_file_diagnostic' "$driver"
rg -Fq 'requested launcher mode is not implemented' "$driver"
rg -Fq 'mode: mutable CliMode' "$runner"
rg -Fq 'def check_elisascript_program_file_diagnostic' "$runner"
rg -Fq 'ExecuteDirectOnly' "$runner"
rg -Fq 'execute_bytecode_direct_only' "$runner"
rg -Fq 'const enum ElisascriptProgramDiagnosticMode of u8:' "$runner"
rg -Fq 'return if mode == ElisascriptProgramDiagnosticMode.VerifyOnly' "$runner"
rg -Fq 'diagnostic_check_accepts_modules_without_main_and_never_executes' "$repo_root/test/ir/elisascript_runner_test.elisa"
rg -Fq 'strict_engine_diagnostic_rejects_interpreter_fallback' "$repo_root/test/ir/elisascript_runner_test.elisa"
rg -Fq 'cli_parser_resets_reused_request_state' "$repo_root/test/ir/elisascript_runner_test.elisa"
rg -Fq 'request.report_format == CliReportFormat.Human' "$repo_root/test/ir/elisascript_runner_test.elisa"
rg -Fq 'bounded C-string scan' "$contract"
rg -Fq -- '--format human|json|junit' "$contract"
rg -Fq -- '--select NAME' "$contract"
rg -Fq 'ArgumentBytes' "$contract"

printf 'cli model audit: typed modes, bounded report formats, exact test selection, and option validation are present; --check validates without executing\n'
