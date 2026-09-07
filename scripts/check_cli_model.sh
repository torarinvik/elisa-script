#!/usr/bin/env bash

# Compiler-free audit for the typed launcher argument boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/cli_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'cli model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsCli:' \
    'CLI_MAX_ARGUMENTS' \
    'CLI_MAX_TEXT_BYTES' \
    'CLI_MAX_SOURCE_PATH_BYTES' \
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
    'MissingOptionValue' \
    'ArgumentLimitExceeded' \
    'SourcePathLimitExceeded' \
    'option_end_seen'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/cli_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_cli_contract_separates_launcher_options_from_script_arguments' \
    'CliMode.Check' \
    'CliColorMode.Never' \
    'CliContractError.DuplicateMode' \
    'CliContractError.UnknownOption'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsCli::CliInvocation`' "$docs"
rg -Fq 'P14 CLI follow-up' "$plan"

printf 'cli model audit: typed modes, option boundaries, script-argument preservation, and bounded validation are present\n'
