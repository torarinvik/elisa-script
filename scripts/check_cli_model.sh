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
plan="$repo_root/IMPLEMENTATION_PLAN.md"
driver="$repo_root/src/driver/elisascript.elisa"
runner="$repo_root/src/ir/runner.elisa"

for required_file in "$model" "$ir" "$fixture" "$contract" "$docs" "$plan" "$driver" "$runner"; do
    [[ -f "$required_file" ]] || { printf 'cli model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsCli:' \
    'const module Limits:' \
    'Limits::ARGUMENTS' \
    'Limits::TEXT_BYTES' \
    'Limits::SOURCE_PATH_BYTES' \
    'const enum CliMode of u8:' \
    'const enum CliColorMode of u8:' \
    'struct CliInvocation:' \
    'error CliContractError:' \
    'def validate_cli_invocation(' \
    'def parse_cli_arguments('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'cli_mode_valid' \
    'cli_color_valid' \
    'cli_mode_requires_source' \
    'DuplicateMode' \
    'DuplicateOption' \
    'UnexpectedArgument' \
    'TestArgumentsUnsupported' \
    'InvalidSourceExtension' \
    'MissingOptionValue' \
    'ArgumentLimitExceeded' \
    'SourcePathLimitExceeded' \
    'option_end_seen' \
    'arguments[index] == "--" and not invocation.option_end_seen'; do
    rg -Fq "$boundary" "$model"
done

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

rg -Fq '`EsCli::CliInvocation`' "$docs"
rg -Fq 'using EsCli' "$driver"
rg -Fq 'request.mode <- invocation.mode' "$driver"
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
rg -Fq 'bounded C-string scan' "$contract"
rg -Fq 'ArgumentBytes' "$contract"
rg -Fq 'P14 CLI follow-up' "$plan"

printf 'cli model audit: typed modes and bounded options are present; --check validates without executing\n'
