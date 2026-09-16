#!/usr/bin/env bash

# Compiler-free audit for lowerer-side @test discovery metadata.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
lowerer="$repo_root/src/ir/lower_ast.elisa"
fixture="$repo_root/test/ir/elisascript_lowering_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$lowerer" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'test metadata audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'struct ElisascriptTestFunction:' \
    'struct LowerResult:' \
    'test_functions: darray[ElisascriptTestFunction]' \
    'const LOWER_TEST_FUNCTIONS_MAX: usize = 4096' \
    'def lower_function_has_test_decorator(' \
    'return LowerResult{module: lowered_module, issues: issues, test_functions: test_functions}'; do
    rg -Fq "$declaration" "$lowerer"
done

for boundary in \
    'lower_function_has_test_decorator(decorators) and params.count == 0 and return_type.kind == TypeKind.Void' \
    'test_functions.count < LOWER_TEST_FUNCTIONS_MAX' \
    'test function count exceeds the bounded discovery limit' \
    'test_function_limit_reported'; do
    rg -Fq "$boundary" "$lowerer"
done

for fixture_pattern in \
    'lower_result_collects_only_valid_top_level_test_metadata' \
    'lowered.test_functions.count == 2' \
    'lowered.test_functions[0].name == "first"' \
    'lowered.test_functions[1].name == "second"' \
    'lowered.module.functions.count == 3'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`LowerResult.test_functions` is the first discovery side channel' "$docs"
rg -Fq 'ES-TEST-003 | `LowerResult.test_functions`' "$ledger"
rg -Fq 'Lowerer test metadata' "$plan"

printf 'test metadata audit: bounded top-level @test discovery metadata is present\n'
