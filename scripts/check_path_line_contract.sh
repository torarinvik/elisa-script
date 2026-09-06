#!/usr/bin/env bash

# Compiler-free audit for the Path line-operation compatibility boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
lowerer="$repo_root/src/ir/lower_ast.elisa"
interpreter="$repo_root/src/ir/interpret.elisa"
bytecode="$repo_root/src/bytecode/bytecode.elisa"
lowering_tests="$repo_root/test/ir/elisascript_lowering_test.elisa"
source_tests="$repo_root/test/ir/elisascript_source_test.elisa"
interpreter_tests="$repo_root/test/ir/elisascript_interpreter_test.elisa"
bytecode_tests="$repo_root/test/ir/elisascript_bytecode_test.elisa"
semantics="$repo_root/docs/semantics.md"
ir_docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$lowerer" "$interpreter" "$bytecode" "$lowering_tests" "$source_tests" "$interpreter_tests" "$bytecode_tests" "$semantics" "$ir_docs" "$plan"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'path line audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q 'callee_name == "read_lines"' "$lowerer"
rg -q 'method_name == "read_lines"' "$lowerer"
rg -q 'Opcode.ReadText' "$lowerer"
rg -q 'Opcode.Split' "$lowerer"
rg -q 'method_name == "write_lines" or method_name == "append_lines"' "$lowerer"
rg -q 'Opcode.Join' "$lowerer"
rg -q 'Opcode.WriteText if method_name == "write_lines" else Opcode.AppendText' "$lowerer"
rg -q 'read_lines requires a nominal Path operand' "$lowerer"
rg -q 'write_lines and Path.append_lines require a darray\[sview\] value' "$lowerer"
rg -q 'def evaluate_split_lines' "$interpreter"
rg -q -i 'trailing delimiter does not' "$interpreter"
rg -q -i 'trailing line breaks do not add an' "$semantics"
rg -q 'Opcode.SplitLines' "$bytecode"
rg -q 'Opcode.Split' "$bytecode"
rg -q 'source_loader_accepts_typed_append_lines' "$source_tests"
rg -q 'interpreter_executes_text_split_lines_aliases' "$interpreter_tests"
rg -q 'bytecode_direct_text_split_lines_matches_reference_interpreter' "$bytecode_tests"
rg -q 'read_lines\(path\).*equivalent' "$semantics"
rg -q 'trailing empty field' "$semantics"
rg -q 'ReadText.*Split|Split.*Join.*WriteText' "$ir_docs"
rg -q 'Q01:.*Path line/append' "$plan"

printf 'path line audit: typed Path line lowering, split semantics, and interpreter/direct-bytecode fixtures present\n'
