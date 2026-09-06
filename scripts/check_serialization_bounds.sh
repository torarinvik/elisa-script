#!/usr/bin/env bash

# Compiler-free audit for the shared serialized-slice admission invariant.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
runtime_model="$repo_root/src/ir/runtime_model.elisa"
bytecode="$repo_root/src/bytecode/bytecode.elisa"
verifier="$repo_root/src/ir/ir_verify.elisa"
tests="$repo_root/test/ir/elisascript_ir_test.elisa"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$runtime_model" "$bytecode" "$verifier" "$tests" "$plan"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'serialization bounds audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q 'def runtime_bounded_slice_end' "$runtime_model"
rg -q 'return false if length > bound - start' "$runtime_model"
rg -q 'runtime_bounded_slice_end\(offset, length_host, bytes.count, end\)' "$bytecode"
rg -q 'length\.usize\(\)\.u64\(\) != length' "$bytecode"
rg -q 'bytecode_artifact_bytes_valid' "$bytecode"
rg -q 'bytecode_block_layout_valid' "$bytecode"
rg -q 'saturat|saturated|range' "$verifier"
rg -q 'serialized_slice_bounds_use_subtraction_before_end_addition' "$tests"
rg -q 'Q02a:' "$plan"
printf 'serialization bounds audit: shared slice admission, bytecode reader, verifier, and fixture present\n'
