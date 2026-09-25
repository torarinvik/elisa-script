#!/usr/bin/env bash

# Compiler-free audit for scoped expression tails and their semantic boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
fixture="$repo_root/test/driver/block_scoped_tail.elisascript"
lowering_test="$repo_root/test/ir/elisascript_lowering_test.elisa"
semantic_test="$repo_root/test/semantic/elisascript_semantic_test.elisa"
lowerer="$repo_root/src/ir/lower_ast.elisa"
closure_checker="$repo_root/vendor/elisa-compiler/src/semantic/check_closure_capture.elisa"
flow_checker="$repo_root/vendor/elisa-compiler/src/semantic/resolve_flow.elisa"

for required_file in "$fixture" "$lowering_test" "$semantic_test" "$lowerer" "$closure_checker" "$flow_checker"; do
    [[ -f "$required_file" ]] || { printf 'block-tail audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -Uq 'def answer\(\) -> i64:\n[[:space:]]+value: i64 =\n[[:space:]]+hidden: i64 = 41\n[[:space:]]+hidden \+ 1\n[[:space:]]+value' "$fixture"
rg -Fq 'capture_process_result(executable("/usr/bin/true"), [], empty_input)' "$fixture"
rg -Fq 'result.exit_status + answer() - 42' "$fixture"
rg -Fq 'function_tail_returns_scoped_block_value' "$lowering_test"
rg -Fq 'scoped_process_value_block_is_not_a_thread_submission' "$semantic_test"
rg -Fq 'arguments: darray[sview]' "$semantic_test"
rg -Fq 'tail_is_value' "$flow_checker"
rg -Fq 'function tail expression does not match its return type' "$lowerer"
rg -Fq 'annotation.name == "__submit"' "$closure_checker"
rg -Fq 'submit_line == block_line.line' "$closure_checker"

printf 'block-tail audit: fixture and source-level lowering/semantic/closure coverage are present; runtime behavior is not asserted\n'
