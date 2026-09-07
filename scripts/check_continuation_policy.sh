#!/usr/bin/env bash

# Compiler-free audit for the continuation-policy decision record.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
policy="$repo_root/docs/continuation-policy.md"
verifier="$repo_root/src/ir/ir_verify.elisa"
lowerer="$repo_root/src/ir/lower_ast.elisa"
tests="$repo_root/test/ir/elisascript_ir_test.elisa"

for required_file in "$policy" "$verifier" "$lowerer" "$tests"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'continuation policy audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

for required_text in \
    'Terminal' 'Linear' 'Affine' 'MultiReplay' 'MultiClone' \
    'zero resumes' 'duplicate resume' 'resume after scope exit' \
    'reentrant' 'cleanup' 'Cancellation' 'InvalidContinuation' \
    'UnsafeMultiShot' 'stable' 'release profile'; do
    if ! rg -q "$required_text" "$policy"; then
        printf 'continuation policy audit: policy omits %s\n' "$required_text" >&2
        exit 1
    fi
done

rg -q 'ContinuationPolicy\.MultiClone' "$verifier"
rg -q 'ContinuationPolicy\.MultiReplay' "$verifier"
rg -q 'capture\.type\.kind in \{TypeKind\.Array, TypeKind\.Map\}' "$verifier"
# Source-declared callback returns must be checked with result metadata on both
# sides; a payload-known predicate here would silently weaken future type rows.
rg -q 'def source_handler_operation_conforms' "$lowerer"
rg -q 'effect_operation_result_is_known\(expected_result\) and effect_operation_result_is_known\(actual_result\)' "$lowerer"
rg -q 'multi_shot_rejects_mutable_aggregate_capture' "$tests"
rg -q 'set_capture: ContinuationCapture' "$tests"
rg -q 'issue_count\(issues, IssueKind\.UnsafeMultiShot\) == 3' "$tests"
printf 'continuation policy audit: decision record, verifier guard, and IR fixture present\n'
