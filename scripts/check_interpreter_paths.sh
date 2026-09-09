#!/usr/bin/env bash

# Compiler-free audit for interpreter POSIX path admission.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
fixture="$repo_root/test/ir/elisascript_interpreter_test.elisa"
bytecode_fixture="$repo_root/test/ir/elisascript_bytecode_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$interpreter" "$fixture" "$bytecode_fixture" "$docs" "$ledger" "$plan"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'interpreter path audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q 'const INTERPRET_MAX_PATH_BYTES: usize = 4096' "$interpreter"
rg -q 'const INTERPRET_MAX_TEMPORARY_PREFIX_BYTES: usize = INTERPRET_MAX_PATH_BYTES - 1 - 17 - 6' "$interpreter"
rg -q 'def path_text_valid\(' "$interpreter"
rg -q 'return false if length == 0 or length >= INTERPRET_MAX_PATH_BYTES' "$interpreter"
rg -q 'return not text_has_nul\(value\)' "$interpreter"
rg -q 'def path_shape_text_valid\(' "$interpreter"
rg -q 'def path_shape_result_valid\(' "$interpreter"
rg -q 'return false if sview_len\(value\) >= INTERPRET_MAX_PATH_BYTES' "$interpreter"
rg -q 'path_shape_result_valid\(bytes_view\(joined\)\)' "$interpreter"
rg -q 'path_shape_result_valid\(bytes_view\(normalized\)\)' "$interpreter"
rg -q 'path_shape_result_valid\(bytes_view\(relative\)\)' "$interpreter"
rg -q 'def path_value_input_valid\(' "$interpreter"
rg -q 'def path_value_output_valid\(' "$interpreter"
rg -q 'def nul_terminated_path\(' "$interpreter"
rg -q 'return \[\] if not path_text_valid\(value\)' "$interpreter"
rg -q 'def host_path_cstring_length_bounded\(' "$interpreter"
rg -q 'while length < INTERPRET_MAX_PATH_BYTES' "$interpreter"
rg -q 'while capacity <= INTERPRET_MAX_PATH_BYTES' "$interpreter"
rg -q 'count.usize\(\) == 0 or count.usize\(\) >= INTERPRET_MAX_PATH_BYTES' "$interpreter"
rg -q 'host_path_cstring_length_bounded\(found_items, too_large\)' "$interpreter"
rg -q 'scanner\.directory <- null' "$interpreter"
rg -q 'c_path: dstr = nul_terminated_path\(' "$interpreter"
rg -q 'c_source: dstr = nul_terminated_path\(' "$interpreter"
rg -q 'c_target: dstr = nul_terminated_path\(' "$interpreter"
rg -q 'working_directory_bytes <- nul_terminated_path\(' "$interpreter"
rg -q 'not path_text_valid\(working_directory\.text\)' "$interpreter"
rg -q 'sview_len\(prefix\.text\) > INTERPRET_MAX_TEMPORARY_PREFIX_BYTES' "$interpreter"
rg -q 'interpreter_rejects_oversized_temporary_prefix_before_nul_scan' "$fixture"
rg -q 'sview\("", 0, 4073\)' "$fixture"
rg -q 'return \[\] if total >= INTERPRET_MAX_PATH_BYTES' "$interpreter"
rg -q 'scanner\.name_bytes > INTERPRET_MAX_DIRECTORY_NAME_BYTES' "$interpreter"
rg -q 'length > INTERPRET_MAX_DIRECTORY_NAME_BYTES - scanner\.name_bytes' "$interpreter"
rg -q 'def path_join_length_fits\(base: sview, leaf: sview\)' "$interpreter"
rg -q 'if not path_join_length_fits\(base\.text, leaf\.text\)' "$interpreter"
rg -q 'if not path_join_length_fits\(path\.text, bytes_view\(name\)\)' "$interpreter"
rg -q 'if not path_join_length_fits\(path\.text, pattern_text\)' "$interpreter"
rg -q 'if not path_text_valid\(pattern\.text\)' "$interpreter"
rg -q 'if not path_shape_result_valid\(bytes_view\(child\)\)' "$interpreter"
rg -q 'if not path_shape_result_valid\(bytes_view\(joined\)\)' "$interpreter"
rg -q 'interpreter_rejects_oversized_glob_before_scan' "$fixture"
rg -q 'sview\("", 0, 4096\)' "$fixture"

if rg -q 'c_(path|source|destination|target|link): dstr = nul_terminated_text\(' "$interpreter"; then
    printf 'interpreter path audit: a filesystem c-string still bypasses path admission\n' >&2
    exit 1
fi

for forbidden in \
    'sview_len(path.text) == 0 or text_has_nul(path.text)' \
    'sview_len(source.text) == 0 or sview_len(destination.text) == 0 or text_has_nul(source.text)' \
    'sview_len(source) == 0 or sview_len(destination) == 0 or text_has_nul(source)' \
    'sview_len(path) == 0 or text_has_nul(path)'; do
    if rg -Fq "$forbidden" "$interpreter"; then
        printf 'interpreter path audit: unbounded path NUL scan remains: %s\n' "$forbidden" >&2
        exit 1
    fi
done

rg -q 'interpreter_rejects_oversized_path_before_c_string_allocation' "$fixture"
rg -q 'interpreter_rejects_oversized_pure_path_before_arena_allocation' "$fixture"
rg -q 'bytecode_direct_rejects_oversized_pure_path_before_arena_allocation' "$bytecode_fixture"
rg -q 'sview\("", 0, 4096\)' "$fixture"
rg -q 'All filesystem text and byte operations reject an empty path' "$docs"
rg -q '4 KiB path admission|4096-byte path|interpreter.*path' "$docs"
rg -q 'ES-FS-001' "$ledger"
rg -q 'interpret\.elisa' "$ledger"
rg -q 'interpreter.*path' "$plan"

printf 'interpreter path audit: bounded path admission precedes C-string scans and host calls\n'
