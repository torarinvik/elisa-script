#!/usr/bin/env bash

# Compiler-free audit for relative and trailing-separator copy-tree paths.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
interpreter="$repo_root/src/ir/interpret.elisa"
fixture="$repo_root/test/ir/elisascript_interpreter_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$interpreter" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || {
        printf 'copy-tree relative-path audit: missing %s\n' "$required_file" >&2
        exit 1
    }
done

rg -q 'def copy_tree_destination_canonical_overlaps_source\(' "$interpreter"
rg -q 'normalized_destination: dstr = Fs::normalize\(&perm_arena, destination\)' "$interpreter"
rg -q 'normalized_destination_text: sview = bytes_view\(normalized_destination\)' "$interpreter"
rg -q 'destination_parent: sview = "\." if parent_spelling == "" else parent_spelling' "$interpreter"
rg -q 'destination_leaf: sview = Fs::filename\(normalized_destination_text\)' "$interpreter"
rg -U -q 'normalized_destination: dstr = Fs::normalize\(&perm_arena, destination\).*parent_spelling: sview = Fs::parent\(normalized_destination_text\)' "$interpreter"
rg -U -q 'destination_parent: sview = "\." if parent_spelling == "" else parent_spelling.*canonical_parent: RuntimeValue = evaluate_path_real\(machine, runtime_text\(destination_parent\)\)' "$interpreter"

rg -q 'interpreter_accepts_relative_and_trailing_slash_tree_destinations' "$fixture"
rg -q 'copy_tree\(path\\"relative-source\\", path\\"relative-destination/\\"\)' "$fixture"
rg -q 'copy_tree\(path\\"relative-source\\", path\\"relative-plain-destination\\"\)' "$fixture"
rg -q 'relative destination.*realpath' "$docs"
rg -q 'relative and trailing-separator destination' "$ledger"
rg -q 'copy-tree relative-path follow-up' "$plan"

printf 'copy-tree relative-path audit: normalized relative/trailing destinations use a real current-directory parent before overlap checks\n'
