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

for required_file in "$lowerer" "$interpreter" "$bytecode" "$lowering_tests" "$source_tests" "$interpreter_tests" "$bytecode_tests" "$semantics" "$ir_docs"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'path line audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q 'def is_path_global_array_io_spec\(' "$lowerer"
rg -q 'spec\.argument_types == "Path" and spec\.opcode == "ReadText" and spec\.return_type == "darray\[text\]"' "$lowerer"
rg -q 'path_spec\.known and path_spec\.opcode == "ReadText"' "$lowerer"
rg -q 'path_spec\.return_type == "darray\[text\]"' "$lowerer"
rg -q 'Opcode.ReadText' "$lowerer"
rg -q 'Opcode.Split' "$lowerer"
rg -q 'path_spec\.known and \(path_spec\.opcode == "WriteText" or path_spec\.opcode == "AppendText"\)' "$lowerer"
rg -q 'Opcode.Join' "$lowerer"
rg -q 'Opcode.AppendText if path_spec\.opcode == "AppendText" else Opcode.WriteText' "$lowerer"
rg -q 'read_lines requires a nominal Path operand' "$lowerer"
rg -q 'Path line writer requires a darray\[sview\] value' "$lowerer"
rg -q 'append_lines requires a nominal Path and darray\[sview\] operands' "$lowerer"
rg -q 'def evaluate_split_lines' "$interpreter"
rg -q -i 'trailing delimiter does not' "$interpreter"
rg -q -i 'trailing line breaks do not add an' "$semantics"
rg -q 'Opcode.SplitLines' "$bytecode"
rg -q 'Opcode.Split' "$bytecode"
rg -q 'source_loader_accepts_typed_append_lines' "$source_tests"
rg -q 'interpreter_executes_text_split_lines_aliases' "$interpreter_tests"
rg -q 'interpreter_read_lines_preserves_trailing_empty_field' "$interpreter_tests"
rg -q 'bytecode_direct_text_split_lines_matches_reference_interpreter' "$bytecode_tests"
rg -q 'bytecode_direct_read_lines_preserves_trailing_empty_field' "$bytecode_tests"
rg -q 'copy_tree_destination_overlaps_source' "$interpreter"
rg -q 'copy_tree_destination_canonical_overlaps_source' "$interpreter"
rg -q 'canonical_parent: RuntimeValue = evaluate_path_real' "$interpreter"
rg -q 'normalized_source: dstr = Fs::normalize\(&perm_arena, source\)' "$interpreter"
rg -q 'without adding an undeclared current-directory read' "$interpreter"
rg -q 'interpreter_rejects_tree_destination_inside_source_before_mutation' "$interpreter_tests"
rg -q 'interpreter_rejects_tree_destination_through_symlink_parent_before_mutation' "$interpreter_tests"
rg -q 'bytecode_direct_tree_overlap_rejection_matches_reference_interpreter' "$bytecode_tests"
rg -q 'bytecode_direct_tree_symlink_parent_rejection_matches_reference_interpreter' "$bytecode_tests"
rg -q 'read_lines\(path\).*equivalent' "$semantics"
rg -q 'trailing empty field' "$semantics"
rg -q 'ReadText.*Split|Split.*Join.*WriteText' "$ir_docs"

printf 'path line audit: typed Path line lowering, split semantics, and interpreter/direct-bytecode fixtures present\n'
