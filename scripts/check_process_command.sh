#!/usr/bin/env bash

# Compiler-free audit for the typed, shell-free process command model.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/process_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'process command audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q '^module EsProcess:' "$model"
rg -q 'include "\.\./runtime/process_model\.elisa"' "$ir"
rg -q '^        const enum ProcessStdioMode of u8:' "$model"
rg -q '^        const enum ProcessEnvironmentMode of u8:' "$model"
rg -q '^        const enum ProcessFailureMode of u8:' "$model"
rg -q '^        struct ProcessCommand:' "$model"
rg -q '^        error ProcessCommandError:' "$model"
rg -q '^            executable: sview$' "$model"
rg -q '^            arguments: darray\[sview\] = \[\]$' "$model"
rg -q '^            working_directory: sview = ""$' "$model"
rg -q '^            environment: darray\[sview\] = \[\]$' "$model"
rg -q '^            timeout_micros: u64 = 0$' "$model"
rg -q 'def validate_process_command\(' "$model"
rg -q 'error\[ProcessCommandError\]' "$model"
rg -q 'process_command_text_has_nul' "$model"
rg -q 'ProcessCommandError\.ArgumentCountExceeded' "$model"
rg -q 'ProcessCommandError\.EnvironmentVectorMalformed' "$model"
rg -q 'ProcessCommandError\.DuplicateEnvironmentName' "$model"
rg -q 'ProcessCommandError\.InvalidStdioMode' "$model"
rg -q 'process_command_text_add_fits' "$model"
rg -q 'sview_len\(value\) >= PROCESS_COMMAND_MAX_TEXT_BYTES' "$model"
rg -q 'sview_contains_byte\(name, 61\)' "$model"
rg -q 'using EsProcess' "$fixture"
rg -q 'typed_process_command_contract_is_shell_free_and_bounded' "$fixture"
rg -q 'ProcessCommandError\.EmbeddedNul' "$fixture"
rg -q 'ProcessCommandError\.DuplicateEnvironmentName' "$fixture"
rg -q 'PROCESS_COMMAND_MAX_ARGUMENTS' "$docs"
rg -q 'validate_process_command' "$docs"
rg -q 'shell-free' "$docs"
rg -q 'P10 typed-command follow-up' "$plan"

printf 'process command audit: typed shell-free command values, bounded vectors, and error[...] validation are present\n'
