#!/usr/bin/env bash

# Compiler-free audit for lowerer-side @test discovery metadata.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
lowerer="$repo_root/src/ir/lower_ast.elisa"
source="$repo_root/src/ir/source.elisa"
source_file="$repo_root/src/ir/source_file.elisa"
fixture="$repo_root/test/ir/elisascript_lowering_test.elisa"
source_fixture="$repo_root/test/ir/elisascript_source_test.elisa"
source_file_fixture="$repo_root/test/ir/elisascript_source_file_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$lowerer" "$source" "$source_file" "$fixture" "$source_fixture" "$source_file_fixture" "$docs" "$ledger"; do
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

for source_declaration in \
    'def lower_elisascript_source_buffer_with_handlers_diagnostic_and_tests(' \
    'def lower_elisascript_source_buffer_with_handlers_tests(' \
    'def lower_elisascript_source_bytes_with_handlers_tests(' \
    'def lower_elisascript_source_with_handlers_tests(' \
    'def lower_elisascript_source_bytes_tests('; do
    rg -Fq "$source_declaration" "$source"
done

for file_declaration in \
    'def lower_elisascript_file_with_handlers_diagnostic_and_tests(' \
    'def lower_elisascript_file_with_handlers_tests(' \
    'def lower_elisascript_file_tests('; do
    rg -Fq "$file_declaration" "$source_file"
done

rg -Fq 'test_functions.truncate(0)' "$source"
rg -Fq 'test_functions.extend(lowered.test_functions)' "$source"
rg -Fq 'test_functions.truncate(0)' "$source_file"
rg -Fq 'lower_elisascript_source_buffer_with_handlers_diagnostic_and_tests(path_items, source_items' "$source_file"

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

for source_fixture_pattern in \
    'source_loader_exposes_top_level_test_metadata' \
    'lower_elisascript_source_with_handlers_tests(' \
    'source_bytes_loader_exposes_owned_test_metadata' \
    'lower_elisascript_source_bytes_tests(' \
    'tests[0].name == "smoke"' \
    'tests[0].name == "bytes_smoke"'; do
    rg -Fq "$source_fixture_pattern" "$source_fixture"
done

for source_file_fixture_pattern in \
    'source_file_loader_exposes_top_level_test_metadata' \
    'lower_elisascript_file_tests(' \
    'tests[0].name == "file_smoke"'; do
    rg -Fq "$source_file_fixture_pattern" "$source_file_fixture"
done

rg -Fq '`LowerResult.test_functions` is the first discovery side channel' "$docs"
rg -Fq 'Source/file loader wrappers preserve the compact' "$docs"
rg -Fq 'ES-TEST-003 | `LowerResult.test_functions`' "$ledger"
rg -Fq 'ES-TEST-004 | source/file test catalog wrappers' "$ledger"

printf 'test metadata audit: bounded top-level @test discovery metadata is present\n'
