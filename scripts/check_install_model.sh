#!/usr/bin/env bash

# Compiler-free audit for typed install and release publication plans.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/install_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'install model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsInstall:' \
    'INSTALL_FORMAT_VERSION' \
    'INSTALL_MAX_TOTAL_ARTIFACT_BYTES' \
    'const enum InstallTarget of u8:' \
    'const enum InstallScope of u8:' \
    'const enum InstallState of u8:' \
    'struct InstallArtifact:' \
    'struct InstallPlan:' \
    'error InstallContractError:' \
    'PackageVersionInvalid' \
    'def validate_install_plan(' \
    'def advance_install_plan('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'SourceExtensionInvalid' \
    'ArtifactBytesExceeded' \
    'total_bytes' \
    'INSTALL_MAX_TOTAL_ARTIFACT_BYTES - total_bytes' \
    'IntegrityMissing' \
    'DuplicateDestination' \
    'plan.state == InstallState.Published' \
    'RollbackNotReady'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/install_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_install_plan_publishes_and_rolls_back_integrity_bound_artifacts' \
    'InstallEvent.Stage' \
    'InstallEvent.Rollback' \
    'InstallContractError.DuplicateDestination' \
    'aggregate_rejected'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsInstall` makes release publication a typed state machine' "$docs"
rg -Fq 'P15 install follow-up' "$plan"

printf 'install model audit: typed artifact targets, integrity admission, publication transitions, and rollback are present\n'
