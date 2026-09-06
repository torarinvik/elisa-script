#!/usr/bin/env bash

# Compiler-free audit for the continuation-policy decision record.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
policy="$repo_root/docs/continuation-policy.md"
verifier="$repo_root/src/ir/ir_verify.elisa"
tests="$repo_root/test/ir/elisascript_ir_test.elisa"

for required_file in "$policy" "$verifier" "$tests"; do
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
rg -q 'multi_shot_rejects_mutable_aggregate_capture' "$tests"
printf 'continuation policy audit: decision record, verifier guard, and IR fixture present\n'
